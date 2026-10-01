import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart' show Nip01Event;

import '../logic/group.dart';
import '../logic/identity.dart';
import '../logic/nip17.dart';
import '../logic/transport.dart';
import '../models/message.dart';
import 'db.dart';
import 'identity_store.dart';
import 'message_store.dart';

/// active: member. pending: invitation from someone I haven't accepted.
/// removed: I was removed (history stays readable, sending disabled).
enum GroupStatus { active, pending, removed }

class GroupEntry {
  const GroupEntry(
    this.state,
    this.status,
    this.since, [
    this.unsent = const {},
  ]);
  final GroupState state;
  final GroupStatus status;

  /// When this phone first saw the group (seconds, local only): sorts groups
  /// that have no messages yet.
  final int since;

  /// Admin only: members the latest state couldn't be delivered to yet.
  final Set<String> unsent;
}

/// Private groups v1: one gift wrap per member, no relay-side group. The
/// admin's signed state decides membership; everything else is dropped.
class GroupStore extends ChangeNotifier {
  GroupStore({
    required IdentityStore identity,
    required DocStore db,
    required Transport transport,
    required MessageStore messages,
    WrapFn wrap = Nip17.wrap,
  }) : _identity = identity,
       _db = db,
       _transport = transport,
       _messages = messages,
       _wrap = wrap {
    _identity.addListener(_syncWithIdentity);
    _syncWithIdentity();
  }

  static const _groupsCollection = 'groups';
  static const _messagesCollection = 'group_messages';

  final IdentityStore _identity;
  final DocStore _db;
  final Transport _transport;
  final MessageStore _messages;
  final WrapFn _wrap;

  Identity? _me;
  StreamSubscription<Nip01Event>? _sub;
  bool _loaded = false;
  final Map<String, GroupEntry> _groups = {};
  final _arrivals = StreamController<Message>.broadcast();

  /// Group messages from others as they arrive (see MessageStore.arrivals).
  Stream<Message> get arrivals => _arrivals.stream;
  final Map<String, Message> _byId = {};

  /// Messages for groups whose state hasn't arrived yet (relays don't keep
  /// order). Memory only, bounded.
  final Map<String, List<Nip01Event>> _early = {};
  static const _earlyCap = 50;
  static const _earlyGroupsCap = 16;

  bool get loaded => _loaded;
  GroupEntry? group(String id) => _groups[id];

  List<GroupEntry> groupsWith(GroupStatus status) =>
      _groups.values.where((g) => g.status == status).toList();

  List<Message> messagesIn(String groupId) =>
      _byId.values.where((m) => m.groupId == groupId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Message? lastIn(String groupId) {
    final all = messagesIn(groupId);
    return all.isEmpty ? null : all.last;
  }

  /// Last activity (seconds): newest message, else when the group arrived.
  int activityOf(String groupId) =>
      lastIn(groupId)?.createdAt ?? _groups[groupId]?.since ?? 0;

  /// Drops memory and re-reads everything from the DB (after a backup
  /// import), keeping the same identity.
  void reload() {
    if (_me == null) return;
    _me = null;
    _syncWithIdentity();
  }

  void _syncWithIdentity() {
    final id = _identity.identity;
    if (id?.publicKey == _me?.publicKey) return;
    // Wipe / lock / switch: memory only, never the DB.
    _sub?.cancel();
    _sub = null;
    _groups.clear();
    _byId.clear();
    _early.clear();
    _loaded = false;
    _me = id;
    notifyListeners();
    if (id != null) unawaited(_start(id));
  }

  Future<void> _start(Identity id) async {
    final groups = await _db.listDocs(_groupsCollection);
    final messages = await _db.listDocs(_messagesCollection);
    if (_me != id) return;
    for (final d in groups) {
      final state = GroupState.fromJson(d['state']);
      if (state == null) continue;
      _groups[state.id] = GroupEntry(
        state,
        GroupStatus.values.byName(d['status'] as String),
        d['since'] as int? ?? 0,
        {...?(d['unsent'] as List?)?.whereType<String>()},
      );
    }
    for (final d in messages) {
      final m = Message.fromJson(d);
      _byId[m.id] = m;
    }
    _sub = _messages.groupRumors.listen(_onRumor);
    _loaded = true;
    notifyListeners();
  }

  // --- admin actions --------------------------------------------------------

  /// Creates a group with accepted contacts. Returns its id.
  Future<String?> create(String name, Set<String> members) async {
    final me = _me;
    final trimmed = name.trim();
    if (me == null || trimmed.isEmpty) return null;
    final all = {me.publicKey, ...members};
    if (all.length > GroupState.maxMembers || all.length < 2) return null;
    final state = GroupState(
      id: GroupState.newId(),
      name: trimmed,
      admin: me.publicKey,
      members: all,
      version: 1,
    );
    await _save(state, GroupStatus.active, me);
    // Don't hold the UI on the network (Tor can take a while to come up).
    unawaited(_broadcast(state, to: all, me: me));
    return state.id;
  }

  Future<void> rename(String groupId, String name) =>
      _adminUpdate(groupId, (s) => s.copyWith(name: name.trim()));

  Future<void> addMembers(String groupId, Set<String> add) =>
      _adminUpdate(groupId, (s) => s.copyWith(members: {...s.members, ...add}));

  Future<void> removeMember(String groupId, String member) => _adminUpdate(
    groupId,
    (s) => s.copyWith(members: {...s.members}..remove(member)),
  );

  Future<void> _adminUpdate(
    String groupId,
    GroupState Function(GroupState) change,
  ) async {
    final me = _me;
    final entry = _groups[groupId];
    if (me == null || entry == null || entry.state.admin != me.publicKey) {
      return;
    }
    final next = change(entry.state);
    if (next.name.isEmpty ||
        next.members.length > GroupState.maxMembers ||
        !next.members.contains(me.publicKey)) {
      return;
    }
    await _save(next, GroupStatus.active, me);
    // Removed members get the new state too: that's how they learn.
    unawaited(
      _broadcast(
        next,
        to: {...entry.state.members, ...next.members, ...entry.unsent},
        me: me,
      ),
    );
  }

  // --- member actions -------------------------------------------------------

  Future<void> accept(String groupId) async {
    final me = _me;
    final entry = _groups[groupId];
    if (me == null || entry == null) return;
    await _save(entry.state, GroupStatus.active, me);
  }

  /// Leaves (member) or refuses an invitation: tells the admin, then forgets
  /// the group and its messages on this phone.
  Future<void> leave(String groupId) async {
    final me = _me;
    final entry = _groups[groupId];
    if (me == null || entry == null || entry.state.admin == me.publicKey) {
      return;
    }
    if (entry.status == GroupStatus.active) {
      try {
        final rumor = Nip01Event(
          pubKey: me.publicKey,
          kind: GroupState.kindLeave,
          tags: [
            ['p', entry.state.admin],
            [GroupState.groupTag, groupId],
          ],
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        await _transport.deliver(
          await _wrap(
            sender: me,
            recipientPubkey: entry.state.admin,
            rumor: rumor,
          ),
        );
      } catch (_) {}
    }
    await _forget(groupId, me);
  }

  // --- messages -------------------------------------------------------------

  Future<void> send(String groupId, String text) async {
    final me = _me;
    final entry = _groups[groupId];
    final trimmed = text.trim();
    if (me == null ||
        entry == null ||
        entry.status != GroupStatus.active ||
        trimmed.isEmpty) {
      return;
    }
    final rumor = _chatRumor(entry.state, me, trimmed);
    final message = Message(
      id: rumor.id,
      peer: me.publicKey,
      fromMe: true,
      text: trimmed,
      createdAt: rumor.createdAt,
      status: MessageStatus.sending,
      groupId: groupId,
    );
    await _put(message, me);
    await _deliver(message, rumor, entry.state, me);
  }

  Future<void> retry(String messageId) async {
    final me = _me;
    final m = _byId[messageId];
    final entry = m == null ? null : _groups[m.groupId];
    if (me == null || m == null || entry == null || !m.fromMe) return;
    final rumor = _chatRumor(entry.state, me, m.text, createdAt: m.createdAt);
    await _put(m.copyWith(status: MessageStatus.sending), me);
    await _deliver(m, rumor, entry.state, me);
  }

  Future<void> retryFailed() async {
    final me = _me;
    if (me == null) return;
    for (final g in _groups.values.toList()) {
      if (g.unsent.isNotEmpty && g.state.admin == me.publicKey) {
        await _broadcast(g.state, to: g.unsent, me: me);
      }
    }
    for (final m in _byId.values.toList()) {
      if (m.fromMe && m.status != MessageStatus.sent) await retry(m.id);
    }
  }

  Nip01Event _chatRumor(
    GroupState state,
    Identity me,
    String text, {
    int? createdAt,
  }) => Nip01Event(
    pubKey: me.publicKey,
    kind: Nip17.kindChat,
    tags: [
      for (final m in state.members)
        if (m != me.publicKey) ['p', m],
      [GroupState.groupTag, state.id],
      ['subject', state.name],
    ],
    content: text,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );

  /// One wrap per member + a self-copy (restore). "Sent" once every member's
  /// wrap was accepted; otherwise "failed" and a retry resends to all
  /// (receivers dedupe by rumor id).
  Future<void> _deliver(
    Message m,
    Nip01Event rumor,
    GroupState state,
    Identity me,
  ) async {
    var ok = true;
    for (final member in state.members) {
      try {
        await _transport.deliver(
          await _wrap(sender: me, recipientPubkey: member, rumor: rumor),
        );
      } catch (_) {
        if (member != me.publicKey) ok = false;
      }
    }
    await _put(
      m.copyWith(status: ok ? MessageStatus.sent : MessageStatus.failed),
      me,
    );
  }

  // --- incoming -------------------------------------------------------------

  Future<void> _onRumor(Nip01Event rumor) async {
    final me = _me;
    if (me == null) return;
    switch (rumor.kind) {
      case GroupState.kindState:
        final state = GroupState.fromRumor(rumor);
        if (state != null) await _onState(state, me);
      case GroupState.kindLeave:
        final id = groupIdOf(rumor);
        final entry = id == null ? null : _groups[id];
        if (entry != null &&
            entry.state.admin == me.publicKey &&
            entry.state.members.contains(rumor.pubKey)) {
          await removeMember(id!, rumor.pubKey);
        }
      case Nip17.kindChat:
        await _onChat(rumor, me);
    }
  }

  Future<void> _onState(GroupState state, Identity me) async {
    final current = _groups[state.id];
    if (!shouldApplyGroupState(current: current?.state, incoming: state)) {
      return;
    }
    final GroupStatus status;
    if (!state.members.contains(me.publicKey)) {
      // Never joined: ignore. Was a member: keep history, read-only.
      if (current == null) return;
      status = GroupStatus.removed;
    } else if (current != null && current.status == GroupStatus.active) {
      status = GroupStatus.active;
    } else {
      // Invitations from people I haven't accepted wait in Requests.
      status = _messages.isAccepted(state.admin) || state.admin == me.publicKey
          ? GroupStatus.active
          : GroupStatus.pending;
    }
    await _save(state, status, me);
    final early = _early.remove(state.id) ?? const [];
    for (final r in early) {
      await _onChat(r, me);
    }
  }

  Future<void> _onChat(Nip01Event rumor, Identity me) async {
    final groupId = groupIdOf(rumor);
    if (groupId == null) return;
    final entry = _groups[groupId];
    if (entry == null) {
      // Group ids are attacker-chosen: bound the number of buckets too.
      if (!_early.containsKey(groupId) && _early.length >= _earlyGroupsCap) {
        return;
      }
      final list = _early.putIfAbsent(groupId, () => []);
      if (list.length < _earlyCap) list.add(rumor);
      return;
    }
    final fromMe = rumor.pubKey == me.publicKey;
    // Only current members may speak; a removed member's late messages and
    // anything after my own removal are dropped.
    if (!entry.state.members.contains(rumor.pubKey)) return;
    if (entry.status == GroupStatus.removed && !fromMe) return;
    if (_byId.containsKey(rumor.id)) {
      final existing = _byId[rumor.id]!;
      if (existing.fromMe && existing.status != MessageStatus.sent) {
        await _put(existing.copyWith(status: MessageStatus.sent), me);
      }
      return;
    }
    final message = Message(
      id: rumor.id,
      peer: rumor.pubKey,
      fromMe: fromMe,
      text: rumor.content,
      createdAt: rumor.createdAt,
      status: fromMe ? MessageStatus.sent : MessageStatus.received,
      groupId: groupId,
    );
    await _put(message, me);
    if (!fromMe && _me == me && entry.status == GroupStatus.active) {
      _arrivals.add(message);
    }
  }

  // --- persistence ----------------------------------------------------------

  Future<void> _broadcast(
    GroupState state, {
    required Set<String> to,
    required Identity me,
  }) async {
    final failed = <String>{};
    for (final member in to) {
      if (member == me.publicKey) continue;
      try {
        await _transport.deliver(
          await _wrap(
            sender: me,
            recipientPubkey: member,
            rumor: state.toRumor(recipient: member),
          ),
        );
      } catch (_) {
        failed.add(member); // Re-sent by retryFailed when back online.
      }
    }
    final entry = _groups[state.id];
    // A newer state may have been broadcast meanwhile: it owns the list.
    if (_me != me || entry == null || entry.state.version != state.version) {
      return;
    }
    final unsent = {...entry.unsent.difference(to), ...failed};
    if (unsent.length == entry.unsent.length &&
        unsent.containsAll(entry.unsent)) {
      return;
    }
    await _save(entry.state, entry.status, me, unsent: unsent);
  }

  Future<void> _save(
    GroupState state,
    GroupStatus status,
    Identity me, {
    Set<String>? unsent,
  }) async {
    if (_me != me) return;
    final current = _groups[state.id];
    final since =
        current?.since ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pending = unsent ?? current?.unsent ?? const <String>{};
    _groups[state.id] = GroupEntry(state, status, since, pending);
    notifyListeners();
    await _db.putDoc(_groupsCollection, {
      'id': state.id,
      'state': state.toJson(),
      'status': status.name,
      'since': since,
      'unsent': pending.toList(),
    });
  }

  Future<void> _put(Message m, Identity me) async {
    if (_me != me) return;
    _byId[m.id] = m;
    notifyListeners();
    await _db.putDoc(
      _messagesCollection,
      m.toJson(),
      updatedAt: m.createdAt * 1000,
    );
  }

  Future<void> _forget(String groupId, Identity me) async {
    if (_me != me) return;
    _groups.remove(groupId);
    final ids = _byId.values
        .where((m) => m.groupId == groupId)
        .map((m) => m.id)
        .toList();
    for (final id in ids) {
      _byId.remove(id);
    }
    notifyListeners();
    await _db.deleteDoc(_groupsCollection, groupId);
    for (final id in ids) {
      if (_me != me) return;
      await _db.deleteDoc(_messagesCollection, id);
    }
  }

  @override
  void dispose() {
    _identity.removeListener(_syncWithIdentity);
    _sub?.cancel();
    _arrivals.close();
    super.dispose();
  }
}
