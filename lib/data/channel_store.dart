import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart' show Nip01Event, Nip01EventModel;

import '../logic/channel.dart';
import '../logic/identity.dart';
import '../logic/nip17.dart';
import '../logic/transport.dart';
import 'db.dart';
import 'identity_store.dart';
import 'message_store.dart';

/// active: followed (or mine). pending: invitation from a contact, waiting.
enum ChannelStatus { active, pending }

class ChannelEntry {
  const ChannelEntry({
    required this.pk,
    required this.contentKey,
    required this.meta,
    required this.status,
    required this.since,
    this.index,
    this.relays = const [],
    this.metaAt = 0,
    this.metaUnsent = false,
    this.invitedBy,
  });

  final String pk;
  final String contentKey;
  final ChannelMeta meta;
  final ChannelStatus status;

  /// When this phone first saw the channel (seconds, local only).
  final int since;

  /// Derivation index when the channel is mine, else null.
  final int? index;
  final List<String> relays;

  /// created_at of the metadata event applied (older ones are ignored).
  final int metaAt;

  /// Mine only: metadata not accepted by any relay yet.
  final bool metaUnsent;

  /// Contact who sent a private invite (local only).
  final String? invitedBy;

  bool get mine => index != null;

  ChannelEntry copyWith({
    ChannelMeta? meta,
    ChannelStatus? status,
    int? metaAt,
    bool? metaUnsent,
  }) => ChannelEntry(
    pk: pk,
    contentKey: contentKey,
    meta: meta ?? this.meta,
    status: status ?? this.status,
    since: since,
    index: index,
    relays: relays,
    metaAt: metaAt ?? this.metaAt,
    metaUnsent: metaUnsent ?? this.metaUnsent,
    invitedBy: invitedBy,
  );

  ChannelInvite get invite => ChannelInvite(
    channelPk: pk,
    contentKey: contentKey,
    name: meta.name,
    public: meta.public,
    relays: relays,
  );

  Map<String, Object?> toJson() => {
    'id': pk,
    'k': contentKey,
    'meta': meta.toJson(),
    'status': status.name,
    'since': since,
    'index': index,
    'relays': relays,
    'metaAt': metaAt,
    'metaUnsent': metaUnsent,
    'invitedBy': invitedBy,
  };

  static ChannelEntry? fromJson(Map<String, dynamic> d) {
    final meta = ChannelMeta.fromJson(
      (d['meta'] as Map?)?.cast<String, Object?>(),
    );
    if (meta == null) return null;
    return ChannelEntry(
      pk: d['id'] as String,
      contentKey: d['k'] as String,
      meta: meta,
      status: ChannelStatus.values.byName(d['status'] as String),
      since: d['since'] as int? ?? 0,
      index: d['index'] as int?,
      relays: [...?(d['relays'] as List?)?.whereType<String>()],
      metaAt: d['metaAt'] as int? ?? 0,
      metaUnsent: d['metaUnsent'] as bool? ?? false,
      invitedBy: d['invitedBy'] as String?,
    );
  }
}

enum PostStatus { sending, sent, failed, received }

class ChannelPost {
  const ChannelPost({
    required this.id,
    required this.channel,
    required this.text,
    required this.createdAt,
    required this.status,
    this.event,
  });

  final String id;
  final String channel;
  final String text;
  final int createdAt;
  final PostStatus status;

  /// Mine, not yet accepted by a relay: the signed event, re-published as is
  /// (same id) on retry.
  final Map<String, dynamic>? event;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  ChannelPost withStatus(PostStatus s) => ChannelPost(
    id: id,
    channel: channel,
    text: text,
    createdAt: createdAt,
    status: s,
    event: s == PostStatus.sent ? null : event,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'channel': channel,
    'text': text,
    'createdAt': createdAt,
    'status': status.name,
    'event': event,
  };

  static ChannelPost fromJson(Map<String, dynamic> d) => ChannelPost(
    id: d['id'] as String,
    channel: d['channel'] as String,
    text: d['text'] as String,
    createdAt: d['createdAt'] as int,
    status: PostStatus.values.byName(d['status'] as String),
    event: (d['event'] as Map?)?.cast<String, dynamic>(),
  );
}

typedef _Reaction = ({String emoji, int at});

/// Broadcast channels: admin-only posts, viewers react anonymously.
class ChannelStore extends ChangeNotifier {
  ChannelStore({
    required IdentityStore identity,
    required DocStore db,
    required ChannelTransport transport,
    required Transport giftTransport,
    required MessageStore messages,
    WrapFn wrap = Nip17.wrap,
  }) : _identity = identity,
       _db = db,
       _transport = transport,
       _gifts = giftTransport,
       _messages = messages,
       _wrap = wrap {
    _identity.addListener(_syncWithIdentity);
    _syncWithIdentity();
  }

  static const _channelsCol = 'channels';
  static const _postsCol = 'channel_posts';
  static const _reactionsCol = 'channel_reactions';

  final IdentityStore _identity;
  final DocStore _db;
  final ChannelTransport _transport;
  final Transport _gifts;
  final MessageStore _messages;
  final WrapFn _wrap;

  Identity? _me;
  bool _loaded = false;
  StreamSubscription<Nip01Event>? _eventsSub;
  StreamSubscription<Nip01Event>? _rumorsSub;

  final Map<String, ChannelEntry> _channels = {};
  final Map<String, ChannelPost> _posts = {};

  /// post id → reactor pubkey → latest reaction.
  final Map<String, Map<String, _Reaction>> _reactions = {};

  /// Own channel keys, by pubkey: mine and the restore candidates.
  final Map<String, (int, ChannelKeys)> _ownKeys = {};

  /// My reaction key per channel.
  final Map<String, ({String privateKey, String publicKey})> _reactKeys = {};

  /// Events already handled (several relays send the same one).
  final Set<String> _seen = {};

  bool get loaded => _loaded;
  ChannelEntry? channel(String pk) => _channels[pk];

  List<ChannelEntry> channelsWith(ChannelStatus status) =>
      _channels.values.where((c) => c.status == status).toList();

  List<ChannelPost> postsIn(String pk) =>
      _posts.values.where((p) => p.channel == pk).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  ChannelPost? lastIn(String pk) {
    final all = postsIn(pk);
    return all.isEmpty ? null : all.last;
  }

  int activityOf(String pk) =>
      lastIn(pk)?.createdAt ?? _channels[pk]?.since ?? 0;

  Map<String, int> reactionsOf(String postId) =>
      countReactions(_reactions[postId] ?? const {});

  /// My current reaction on [postId], or null.
  String? myReactionOn(String channelPk, String postId) {
    final key = _reactKeys[channelPk];
    final r = key == null ? null : _reactions[postId]?[key.publicKey];
    return (r == null || r.emoji.isEmpty) ? null : r.emoji;
  }

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
    _eventsSub?.cancel();
    _rumorsSub?.cancel();
    _eventsSub = null;
    _rumorsSub = null;
    _channels.clear();
    _posts.clear();
    _reactions.clear();
    _ownKeys.clear();
    _reactKeys.clear();
    _seen.clear();
    _loaded = false;
    _me = id;
    if (id == null) _transport.watchChannels(const {});
    notifyListeners();
    if (id != null) unawaited(_start(id));
  }

  Future<void> _start(Identity id) async {
    final channels = await _db.listDocs(_channelsCol);
    final posts = await _db.listDocs(_postsCol);
    final reactions = await _db.listDocs(_reactionsCol);
    final own = <(int, ChannelKeys)>[
      for (var i = 0; i < Channel.recoverScan; i++)
        (i, await ChannelKeys.derive(id, i)),
    ];
    if (_me != id) return;
    for (final (i, k) in own) {
      _ownKeys[k.publicKey] = (i, k);
    }
    for (final d in channels) {
      final c = ChannelEntry.fromJson(d);
      if (c == null) continue;
      _channels[c.pk] = c;
      if (c.index != null && !_ownKeys.containsKey(c.pk)) {
        final k = await ChannelKeys.derive(id, c.index!);
        _ownKeys[k.publicKey] = (c.index!, k);
      }
    }
    for (final d in posts) {
      final p = ChannelPost.fromJson(d);
      _posts[p.id] = p;
    }
    for (final d in reactions) {
      final post = d['post'] as String;
      (_reactions[post] ??= {})[d['reactor'] as String] = (
        emoji: d['emoji'] as String,
        at: d['at'] as int,
      );
    }
    for (final c in _channels.values) {
      _reactKeys[c.pk] = await reactionKey(id, c.pk);
    }
    if (_me != id) return;
    _eventsSub = _transport.channelEvents.listen(_onEvent);
    _rumorsSub = _messages.otherRumors.listen(_onRumor);
    _rewatch();
    _loaded = true;
    notifyListeners();
  }

  /// Followed channels, plus my own unused derivation slots so a restored
  /// account finds its channels again.
  void _rewatch() {
    if (_me == null) return;
    final active = {
      for (final c in _channels.values)
        if (c.status == ChannelStatus.active) c.pk,
    };
    _transport.watchChannels(
      {...active, ..._ownKeys.keys},
      relays: {
        for (final c in _channels.values)
          if (c.status == ChannelStatus.active) ...c.relays,
      }.toList(),
    );
  }

  // --- admin ----------------------------------------------------------------

  /// Creates my next channel. [relays]: where viewers should look (ours).
  Future<String?> create({
    required String name,
    String about = '',
    required bool public,
    required List<String> relays,
  }) async {
    final me = _me;
    final meta = ChannelMeta.fromJson(
      ChannelMeta(
        name: name.trim(),
        about: about.trim(),
        public: public,
      ).toJson(),
    );
    if (me == null || meta == null) return null;
    final used = {
      for (final c in _channels.values)
        if (c.index != null) c.index!,
    };
    var index = 0;
    while (used.contains(index)) {
      index++;
    }
    final keys = await ChannelKeys.derive(me, index);
    if (_me != me) return null;
    _ownKeys[keys.publicKey] = (index, keys);
    _reactKeys[keys.publicKey] = await reactionKey(me, keys.publicKey);
    final entry = ChannelEntry(
      pk: keys.publicKey,
      contentKey: keys.contentKey,
      meta: meta,
      status: ChannelStatus.active,
      since: _now(),
      index: index,
      relays: relays,
      metaUnsent: true,
    );
    await _saveChannel(entry, me);
    _rewatch();
    unawaited(_publishMeta(entry, me));
    return entry.pk;
  }

  Future<void> editMeta(String pk, {String? name, String? about}) async {
    final me = _me;
    final c = _channels[pk];
    if (me == null || c == null || !c.mine) return;
    final meta = ChannelMeta.fromJson(
      ChannelMeta(
        name: (name ?? c.meta.name).trim(),
        about: (about ?? c.meta.about).trim(),
        public: c.meta.public,
      ).toJson(),
    );
    if (meta == null) return;
    final next = c.copyWith(meta: meta, metaUnsent: true);
    await _saveChannel(next, me);
    unawaited(_publishMeta(next, me));
  }

  Future<void> _publishMeta(ChannelEntry c, Identity me) async {
    final keys = _ownKeys[c.pk]?.$2;
    if (keys == null) return;
    final event = await signMeta(keys, c.meta);
    try {
      await _transport.publishChannelEvent(event, relays: c.relays);
    } catch (_) {
      return; // metaUnsent stays true: retried by retryFailed.
    }
    final now = _channels[c.pk];
    if (now == null || _me != me) return;
    await _saveChannel(
      now.copyWith(
        // Edited again while this one was in flight: that one is unsent.
        metaUnsent: now.meta != c.meta,
        metaAt: event.createdAt,
      ),
      me,
    );
  }

  Future<void> post(String pk, String text) async {
    final me = _me;
    final c = _channels[pk];
    final keys = _ownKeys[pk]?.$2;
    final trimmed = text.trim();
    if (me == null ||
        c == null ||
        !c.mine ||
        keys == null ||
        trimmed.isEmpty ||
        trimmed.length > Channel.maxPost) {
      return;
    }
    final event = await signPost(keys, trimmed);
    _seen.add(event.id);
    final p = ChannelPost(
      id: event.id,
      channel: pk,
      text: trimmed,
      createdAt: event.createdAt,
      status: PostStatus.sending,
      event: Nip01EventModel.fromEntity(event).toJson(),
    );
    await _putPost(p, me);
    await _publishPost(p, me);
  }

  Future<void> _publishPost(ChannelPost p, Identity me) async {
    final c = _channels[p.channel];
    final raw = p.event;
    if (c == null || raw == null) return;
    try {
      await _transport.publishChannelEvent(
        Nip01EventModel.fromJson(raw),
        relays: c.relays,
      );
      await _putPost(p.withStatus(PostStatus.sent), me);
    } catch (_) {
      await _putPost(p.withStatus(PostStatus.failed), me);
    }
  }

  Future<void> retry(String postId) async {
    final me = _me;
    final p = _posts[postId];
    if (me == null || p == null || p.event == null) return;
    await _putPost(p.withStatus(PostStatus.sending), me);
    await _publishPost(_posts[postId]!, me);
  }

  Future<void> retryFailed() async {
    final me = _me;
    if (me == null) return;
    for (final c in _channels.values.toList()) {
      if (c.mine && c.metaUnsent) await _publishMeta(c, me);
    }
    for (final p in _posts.values.toList()) {
      if (p.event != null && p.status != PostStatus.sent) await retry(p.id);
    }
  }

  /// Sends a private invite to accepted contacts, one gift wrap each.
  Future<void> inviteContacts(String pk, Set<String> contacts) async {
    final me = _me;
    final c = _channels[pk];
    if (me == null || c == null || !c.mine) return;
    for (final to in contacts) {
      if (!_messages.isAccepted(to)) continue;
      final rumor = Nip01Event(
        pubKey: me.publicKey,
        kind: Channel.kindInvite,
        tags: [
          ['p', to],
        ],
        content: jsonEncode(c.invite.toJson()),
        createdAt: _now(),
      );
      try {
        await _gifts.deliver(
          await _wrap(sender: me, recipientPubkey: to, rumor: rumor),
        );
      } catch (_) {
        // Best effort; the admin can invite again.
      }
    }
  }

  // --- viewer ---------------------------------------------------------------

  /// Follows a channel from an invite code / QR. Returns its pubkey.
  Future<String?> join(ChannelInvite invite) async {
    final me = _me;
    if (me == null) return null;
    final existing = _channels[invite.channelPk];
    if (existing != null) {
      if (existing.status == ChannelStatus.pending) {
        await accept(invite.channelPk);
      }
      return invite.channelPk;
    }
    await _addFollowed(invite, ChannelStatus.active, me);
    return invite.channelPk;
  }

  Future<void> accept(String pk) async {
    final me = _me;
    final c = _channels[pk];
    if (me == null || c == null) return;
    await _saveChannel(c.copyWith(status: ChannelStatus.active), me);
    _rewatch();
  }

  /// Unfollows (or refuses an invite): forgets everything locally. Nothing
  /// is sent — the admin never learns who follows.
  Future<void> leave(String pk) async {
    final me = _me;
    final c = _channels[pk];
    if (me == null || c == null || c.mine) return;
    _channels.remove(pk);
    final posts = _posts.values.where((p) => p.channel == pk).toList();
    for (final p in posts) {
      _posts.remove(p.id);
    }
    final reactions = <String>[];
    for (final p in posts) {
      final byReactor = _reactions.remove(p.id);
      if (byReactor == null) continue;
      reactions.addAll(byReactor.keys.map((r) => '${p.id}:$r'));
    }
    _rewatch();
    notifyListeners();
    await _db.deleteDoc(_channelsCol, pk);
    for (final p in posts) {
      if (_me != me) return;
      await _db.deleteDoc(_postsCol, p.id);
    }
    for (final id in reactions) {
      if (_me != me) return;
      await _db.deleteDoc(_reactionsCol, id);
    }
  }

  /// Sets my reaction; the same emoji again removes it.
  Future<void> react(String channelPk, String postId, String emoji) async {
    final me = _me;
    final c = _channels[channelPk];
    final key = _reactKeys[channelPk];
    if (me == null ||
        c == null ||
        c.status != ChannelStatus.active ||
        key == null ||
        !Channel.emojis.contains(emoji) ||
        _posts[postId]?.channel != channelPk) {
      return;
    }
    final current = myReactionOn(channelPk, postId);
    final next = current == emoji ? '' : emoji;
    final prev = _reactions[postId]?[key.publicKey];
    // Strictly newer than what we hold, even within the same second.
    final at = prev != null && prev.at >= _now() ? prev.at + 1 : _now();
    final event = await signReaction(
      key: key,
      channelPk: c.pk,
      contentKey: c.contentKey,
      postId: postId,
      emoji: next,
      createdAt: at,
    );
    _seen.add(event.id);
    await _putReaction(postId, key.publicKey, (emoji: next, at: at), me);
    try {
      await _transport.publishChannelEvent(event, relays: c.relays);
    } catch (_) {
      // Local only until the next reaction goes through; v1 keeps it simple.
    }
  }

  // --- incoming -------------------------------------------------------------

  Future<void> _onEvent(Nip01Event e) async {
    final me = _me;
    if (me == null || !_seen.add(e.id)) return;
    switch (e.kind) {
      case Channel.kindPost:
      case Channel.kindMeta:
        await _onAuthored(e, me);
      case Channel.kindReaction:
        await _onReaction(e, me);
    }
  }

  Future<void> _onAuthored(Nip01Event e, Identity me) async {
    var c = _channels[e.pubKey];
    final own = _ownKeys[e.pubKey];
    // Only followed channels, or my own (restore).
    if (c == null && own == null) return;
    if (c != null && c.status != ChannelStatus.active) return;
    if (!await Nip17.verifySigned(e)) return;
    if (_me != me) return;
    final contentKey = c?.contentKey ?? own!.$2.contentKey;
    final clear = await decryptFor(contentKey, e.pubKey, e.kind, e.content);
    if (clear == null || _me != me) return;

    if (e.kind == Channel.kindMeta) {
      final meta = ChannelMeta.fromJson(clear);
      if (meta == null) return;
      c = _channels[e.pubKey];
      if (c == null) {
        // One of my channels, found again after a restore.
        final (index, keys) = own!;
        _reactKeys[keys.publicKey] = await reactionKey(me, keys.publicKey);
        await _saveChannel(
          ChannelEntry(
            pk: keys.publicKey,
            contentKey: keys.contentKey,
            meta: meta,
            status: ChannelStatus.active,
            since: e.createdAt,
            index: index,
            metaAt: e.createdAt,
          ),
          me,
        );
        _rewatch();
      } else if (e.createdAt > c.metaAt && !c.metaUnsent) {
        await _saveChannel(c.copyWith(meta: meta, metaAt: e.createdAt), me);
      }
      return;
    }

    final text = clear['t'];
    if (text is! String || text.isEmpty || text.length > Channel.maxPost) {
      return;
    }
    // A restored admin may see posts before metadata: keep them anyway.
    final existing = _posts[e.id];
    if (existing != null) {
      if (existing.status != PostStatus.sent &&
          existing.status != PostStatus.received) {
        await _putPost(existing.withStatus(PostStatus.sent), me);
      }
      return;
    }
    await _putPost(
      ChannelPost(
        id: e.id,
        channel: e.pubKey,
        text: text,
        createdAt: e.createdAt,
        status: own != null ? PostStatus.sent : PostStatus.received,
      ),
      me,
    );
  }

  Future<void> _onReaction(Nip01Event e, Identity me) async {
    String? pk;
    for (final t in e.tags) {
      if (t.length > 1 && t[0] == 'p') pk = t[1];
    }
    final c = pk == null ? null : _channels[pk];
    if (c == null || c.status != ChannelStatus.active) return;
    if (!await Nip17.verifySigned(e)) return;
    final clear = await decryptFor(
      c.contentKey,
      c.pk,
      Channel.kindReaction,
      e.content,
    );
    if (clear == null || _me != me) return;
    final postId = clear['e'], emoji = clear['r'];
    if (!Channel.isHex64(postId) || emoji is! String) return;
    if (emoji.isNotEmpty && !Channel.emojis.contains(emoji)) return;
    // Reactions to posts of another channel don't count here.
    final post = _posts[postId];
    if (post != null && post.channel != c.pk) return;
    final current = _reactions[postId]?[e.pubKey];
    if (!newerReaction(current, e.createdAt)) return;
    await _putReaction(postId as String, e.pubKey, (
      emoji: emoji,
      at: e.createdAt,
    ), me);
  }

  Future<void> _onRumor(Nip01Event rumor) async {
    final me = _me;
    if (me == null || rumor.kind != Channel.kindInvite) return;
    // Invites only from people I accepted: no channel spam from strangers.
    if (!_messages.isAccepted(rumor.pubKey)) return;
    final ChannelInvite? invite;
    try {
      invite = ChannelInvite.fromJson(jsonDecode(rumor.content));
    } catch (_) {
      return;
    }
    if (invite == null || _channels.containsKey(invite.channelPk)) return;
    if (_ownKeys.containsKey(invite.channelPk)) return;
    await _addFollowed(
      invite,
      ChannelStatus.pending,
      me,
      invitedBy: rumor.pubKey,
    );
  }

  Future<void> _addFollowed(
    ChannelInvite invite,
    ChannelStatus status,
    Identity me, {
    String? invitedBy,
  }) async {
    _reactKeys[invite.channelPk] = await reactionKey(me, invite.channelPk);
    await _saveChannel(
      ChannelEntry(
        pk: invite.channelPk,
        contentKey: invite.contentKey,
        meta: ChannelMeta(name: invite.name, public: invite.public),
        status: status,
        since: _now(),
        relays: invite.relays,
        invitedBy: invitedBy,
      ),
      me,
    );
    _rewatch();
  }

  // --- persistence ----------------------------------------------------------

  Future<void> _saveChannel(ChannelEntry c, Identity me) async {
    if (_me != me) return;
    _channels[c.pk] = c;
    notifyListeners();
    await _db.putDoc(_channelsCol, c.toJson());
  }

  Future<void> _putPost(ChannelPost p, Identity me) async {
    if (_me != me) return;
    _posts[p.id] = p;
    notifyListeners();
    await _db.putDoc(_postsCol, p.toJson(), updatedAt: p.createdAt * 1000);
  }

  Future<void> _putReaction(
    String postId,
    String reactor,
    _Reaction r,
    Identity me,
  ) async {
    if (_me != me) return;
    (_reactions[postId] ??= {})[reactor] = r;
    notifyListeners();
    await _db.putDoc(_reactionsCol, {
      'id': '$postId:$reactor',
      'post': postId,
      'reactor': reactor,
      'emoji': r.emoji,
      'at': r.at,
    });
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void dispose() {
    _identity.removeListener(_syncWithIdentity);
    _eventsSub?.cancel();
    _rumorsSub?.cancel();
    super.dispose();
  }
}
