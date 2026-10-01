import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart' show Nip01Event;

import '../logic/identity.dart';
import '../logic/nickname.dart';
import '../logic/nip17.dart';
import '../logic/photo.dart';
import '../logic/transport.dart';
import 'db.dart';
import 'identity_store.dart';
import '../models/message.dart';
import 'message_store.dart';

/// My profile photo and nickname, and the ones my contacts sent me.
///
/// They travel only as encrypted profile cards to *accepted* contacts, once
/// per version; receivers cache them in their encrypted DB. A pending
/// contact's card is kept but not shown until I accept them. Nicknames are
/// handed to [MessageStore], which owns display names.
class ProfileStore extends ChangeNotifier {
  ProfileStore({
    required IdentityStore identity,
    required DocStore db,
    required Transport transport,
    required MessageStore messages,
    Future<Uint8List> Function(Uint8List raw)? processPhoto,
    WrapFn wrap = Nip17.wrap,
  }) : _identity = identity,
       _db = db,
       _transport = transport,
       _messages = messages,
       _process = processPhoto ?? ((raw) => compute(processProfilePhoto, raw)),
       _wrap = wrap {
    _identity.addListener(_syncWithIdentity);
    _messages.addListener(_onMessagesChanged);
    _syncWithIdentity();
  }

  final IdentityStore _identity;
  final DocStore _db;
  final Transport _transport;
  final MessageStore _messages;
  final Future<Uint8List> Function(Uint8List raw) _process;
  final WrapFn _wrap;

  Identity? _me;
  StreamSubscription<Nip01Event>? _sub;

  int _myVersion = 0;
  Uint8List? _myPhoto;
  String? _myName;
  final Map<String, _Card> _cards = {};

  /// Cards from pubkeys I have no contact state for yet — typically a card
  /// that overtook its sender's first message. Memory only (a stranger can't
  /// make me write to disk), capped, promoted once the contact exists.
  final Map<String, _Card> _limbo = {};
  static const _limboCap = 20;

  /// Per contact: my card version they have, and whether I already asked
  /// them for theirs.
  final Map<String, (int, bool)> _sent = {};
  bool _syncing = false;
  bool _syncAgain = false;

  /// False until [_start] has read my version and what each contact already
  /// has. Syncing before that would re-send (a stale v0) card on every
  /// launch — noise that also tells relays the app just opened.
  bool _loaded = false;

  Uint8List? get myPhoto => _myPhoto;

  /// My nickname, null when I use the name derived from my key.
  String? get myName => _myName;

  /// Photo to display for [pubkey]: mine, or an accepted contact's.
  Uint8List? photoOf(String pubkey) {
    if (pubkey == _me?.publicKey) return _myPhoto;
    if (!_messages.isAccepted(pubkey)) return null;
    return _cards[pubkey]?.image;
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
    // Wiped or switched: memory only, never the DB (it's being destroyed).
    _sub?.cancel();
    _sub = null;
    _myVersion = 0;
    _myPhoto = null;
    _myName = null;
    _cards.clear();
    _limbo.clear();
    _sent.clear();
    _loaded = false;
    _me = id;
    notifyListeners();
    if (id != null) unawaited(_start(id));
  }

  Future<void> _start(Identity id) async {
    final me = await _db.getDoc('profile', 'me');
    final cards = await _db.listDocs('avatars');
    final sent = await _db.listDocs('profile_sent');
    if (_me != id) return;
    _myVersion = (me?['v'] as int?) ?? 0;
    _myPhoto = _decode(me?['image']);
    _myName = me?['name'] as String?;
    for (final d in cards) {
      final from = d['id'] as String;
      _cards[from] = (
        v: d['v'] as int,
        image: _decode(d['image']),
        name: d['name'] as String?,
      );
      _messages.setNickname(from, _cards[from]!.name);
    }
    for (final d in sent) {
      _sent[d['id'] as String] = (d['v'] as int, d['asked'] == true);
    }
    _sub = _messages.otherRumors.listen(_onRumor);
    _loaded = true;
    notifyListeners();
    _scheduleSync();
  }

  /// Processes (square, small, **metadata stripped**) and shares [raw].
  /// Throws [FormatException] / [PhotoTooLargeException] on bad input.
  Future<void> setPhoto(Uint8List raw) async {
    final me = _me;
    if (me == null) return;
    final processed = await _process(raw);
    await _saveMine(_myVersion + 1, processed, _myName, me);
  }

  Future<void> removePhoto() async {
    final me = _me;
    if (me == null || _myPhoto == null) return;
    await _saveMine(_myVersion + 1, null, _myName, me);
  }

  /// Sets (or with null / blank, removes) my nickname and shares it.
  Future<void> setName(String? name) async {
    final me = _me;
    final clean = sanitizeNickname(name);
    if (me == null || clean == _myName) return;
    await _saveMine(_myVersion + 1, _myPhoto, clean, me);
  }

  Future<void> _saveMine(
    int version,
    Uint8List? image,
    String? name,
    Identity owner,
  ) async {
    if (_me != owner) return;
    _myVersion = version;
    _myPhoto = image;
    _myName = name;
    notifyListeners();
    await _db.putDoc('profile', {
      'id': 'me',
      'v': version,
      'image': image == null ? null : base64Encode(image),
      'name': name,
    });
    _scheduleSync();
  }

  Future<void> _onRumor(Nip01Event rumor) async {
    final me = _me;
    final card = ProfileCard.fromRumor(rumor);
    if (me == null || card == null) return;
    final from = rumor.pubKey;
    // MessageStore already dropped blocked peers.
    if (_messages.stateOf(from) == null) {
      final held = _limbo[from];
      if (held == null || card.version > held.v) {
        _limbo.remove(from);
        if (_limbo.length >= _limboCap) _limbo.remove(_limbo.keys.first);
        _limbo[from] = (v: card.version, image: card.image, name: card.name);
      }
      return;
    }
    await _storeCard(from, (
      v: card.version,
      image: card.image,
      name: card.name,
    ), me);
    if (card.wantsYours && _messages.isAccepted(from)) {
      await _sendCard(from, me, force: true);
    }
  }

  Future<void> _storeCard(String from, _Card card, Identity me) async {
    final current = _cards[from];
    if (current != null && card.v <= current.v) return;
    _cards[from] = card;
    _messages.setNickname(from, card.name);
    notifyListeners();
    if (_me != me) return;
    await _db.putDoc('avatars', {
      'id': from,
      'v': card.v,
      'image': card.image == null ? null : base64Encode(card.image!),
      'name': card.name,
    });
  }

  /// Refused (no state) or blocked contacts leave no photo behind.
  Future<void> _forgetDropped(Identity me) async {
    for (final from in _cards.keys.toList()) {
      final state = _messages.stateOf(from);
      if (state != null && state != ContactState.blocked) continue;
      _cards.remove(from);
      _sent.remove(from);
      _messages.setNickname(from, null);
      notifyListeners();
      if (_me != me) return;
      await _db.deleteDoc('avatars', from);
      await _db.deleteDoc('profile_sent', from);
    }
  }

  /// A held card's sender now has a request or a chat: keep it for real.
  Future<void> _promoteLimbo(Identity me) async {
    for (final from in _limbo.keys.toList()) {
      final state = _messages.stateOf(from);
      if (state == null) continue;
      final card = _limbo.remove(from)!;
      if (state != ContactState.blocked) await _storeCard(from, card, me);
    }
  }

  /// Accepting someone makes their photo visible (see [photoOf]) and may
  /// require sending mine.
  void _onMessagesChanged() {
    notifyListeners();
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_me == null || !_loaded) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    unawaited(_sync());
  }

  /// Brings every accepted contact up to date with my current card, and asks
  /// for theirs when I never got it. Retried on each change (e.g. relays back
  /// online) until delivered.
  Future<void> _sync() async {
    final me = _me;
    if (me == null) return;
    _syncing = true;
    try {
      await _promoteLimbo(me);
      await _forgetDropped(me);
      for (final peer in _messages.acceptedPeers.toList()) {
        if (_me != me) return;
        await _sendCard(peer, me);
      }
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        _scheduleSync();
      }
    }
  }

  Future<void> _sendCard(String peer, Identity me, {bool force = false}) async {
    if (!_messages.isAccepted(peer)) return; // never to pending/blocked
    final (sentVersion, asked) = _sent[peer] ?? (-1, false);
    final needMine = force || sentVersion != _myVersion;
    final needTheirs = !_cards.containsKey(peer) && !asked;
    if (!needMine && !needTheirs) return;
    // Nothing to share and nothing to ask: stay silent.
    if (_myVersion == 0 && !needTheirs) return;

    final card = ProfileCard(
      version: _myVersion,
      image: _myPhoto,
      name: _myName,
      wantsYours: needTheirs,
    );
    try {
      final wrap = await _wrap(
        sender: me,
        recipientPubkey: peer,
        rumor: card.toRumor(sender: me.publicKey, recipient: peer),
      );
      await _transport.deliver(wrap);
    } catch (_) {
      return; // Offline: the next sync retries.
    }
    if (_me != me) return;
    // Record what was actually sent: the photo may have changed while this
    // delivery was in flight, and that newer version still has to go out.
    _sent[peer] = (card.version, asked || needTheirs);
    await _db.putDoc('profile_sent', {
      'id': peer,
      'v': card.version,
      'asked': asked || needTheirs,
    });
  }

  /// Public hook: e.g. relays just came back online.
  void retry() => _scheduleSync();

  static Uint8List? _decode(Object? b64) =>
      b64 is String ? base64Decode(b64) : null;

  @override
  void dispose() {
    _identity.removeListener(_syncWithIdentity);
    _messages.removeListener(_onMessagesChanged);
    _sub?.cancel();
    super.dispose();
  }
}

/// A contact's latest profile card.
typedef _Card = ({int v, Uint8List? image, String? name});
