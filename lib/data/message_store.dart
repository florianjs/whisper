import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart' show Nip01Event;

import '../logic/group.dart';
import '../logic/identity.dart';
import '../logic/image_transfer.dart';
import '../logic/nip17.dart';
import '../logic/photo.dart';
import '../logic/transport.dart';
import '../models/message.dart';
import 'db.dart';
import 'identity_store.dart';

typedef WrapFn =
    Future<Nip01Event> Function({
      required Identity sender,
      required String recipientPubkey,
      required Nip01Event rumor,
    });
typedef AnonymizeFn =
    Future<({Uint8List bytes, int width, int height})> Function(Uint8List raw);

typedef UnwrapFn =
    Future<Nip01Event> Function({
      required Identity me,
      required Nip01Event giftWrap,
    });

/// 1:1 conversations. Decrypted messages live only in memory and in the
/// SQLCipher DB; the network only ever sees gift wraps.
class MessageStore extends ChangeNotifier {
  MessageStore({
    required IdentityStore identity,
    required DocStore db,
    required Transport transport,
    WrapFn wrap = Nip17.wrap,
    UnwrapFn unwrap = Nip17.unwrap,
    AnonymizeFn? anonymize,
    this.chunkPacing = const Duration(milliseconds: 120),
  }) : _identity = identity,
       _db = db,
       _transport = transport,
       _wrap = wrap,
       _unwrap = unwrap,
       _anonymize = anonymize ?? ((raw) => compute(anonymizeChatImage, raw)) {
    _identity.addListener(_syncWithIdentity);
    _syncWithIdentity();
  }

  static const _collection = 'messages';
  static const _contactsCollection = 'contacts';
  static const _imagesCollection = 'images';
  static const _infoCollection = 'contact_info';

  final IdentityStore _identity;
  final DocStore _db;
  final Transport _transport;
  final WrapFn _wrap;
  final UnwrapFn _unwrap;
  final AnonymizeFn _anonymize;

  /// Gap between image chunks, so bursts don't trip relay rate limits.
  final Duration chunkPacing;

  final _reassembler = Reassembler();

  /// Decrypted images by file id (memory cache over the encrypted DB).
  final Map<String, Uint8List> _images = {};

  /// Complete images from *pending* requests: memory only, written to the DB
  /// on accept, dropped on refuse/block/restart.
  final Map<String, Uint8List> _heldImages = {};

  /// Outgoing image progress: message id → (chunks sent, total).
  final Map<String, (int, int)> _sendProgress = {};

  Identity? _me;
  StreamSubscription<Nip01Event>? _sub;

  /// False while the encrypted DB is being opened and read (SQLCipher's key
  /// derivation can take seconds on slow phones): the UI must show "loading",
  /// not "no conversations", or users think their history is gone.
  bool _loaded = false;
  bool get loaded => _loaded;
  final Map<String, Message> _byId = {};
  final Map<String, ContactState> _contacts = {};

  /// Local-only details about a contact: nickname, safety number verified.
  final Map<String, ({String? alias, bool verified})> _info = {};

  String? aliasOf(String peer) => _info[peer]?.alias;
  bool isVerified(String peer) => _info[peer]?.verified ?? false;

  /// Nicknames contacts chose for themselves, fed by ProfileStore from
  /// their profile cards. Memory only: ProfileStore persists the cards.
  final Map<String, String> _nicknames = {};

  /// The nickname [peer] chose; only shown once I accepted them.
  String? nicknameOf(String peer) => isAccepted(peer) ? _nicknames[peer] : null;

  void setNickname(String peer, String? name) {
    if (_nicknames[peer] == name) return;
    name == null ? _nicknames.remove(peer) : _nicknames[peer] = name;
    notifyListeners();
  }

  /// The name I gave them, else the one they chose, else the name derived
  /// from their key.
  String displayName(String peer) =>
      aliasOf(peer) ?? nicknameOf(peer) ?? usernameFor(peer);
  final _otherRumors = StreamController<Nip01Event>.broadcast();
  final _groupRumors = StreamController<Nip01Event>.broadcast();
  final _arrivals = StreamController<Message>.broadcast();

  /// Messages from others as they arrive (history replays included: filter
  /// on [Message.createdAt]). Drives notifications.
  Stream<Message> get arrivals => _arrivals.stream;

  /// Group states and group chat messages (mine included, for restore),
  /// from non-blocked authors. Handled by GroupStore.
  Stream<Nip01Event> get groupRumors => _groupRumors.stream;

  /// Decrypted non-chat rumors (e.g. profile cards) from non-blocked peers.
  Stream<Nip01Event> get otherRumors => _otherRumors.stream;

  Iterable<String> get blockedPeers => _contacts.entries
      .where((e) => e.value == ContactState.blocked)
      .map((e) => e.key);

  Iterable<String> get acceptedPeers => _contacts.entries
      .where((e) => e.value == ContactState.accepted)
      .map((e) => e.key);
  final Set<String> _seenWraps = {};

  List<Conversation> _conversationsIn(ContactState state) {
    final last = <String, Message>{};
    for (final m in _byId.values) {
      if (_contacts[m.peer] != state) continue;
      final current = last[m.peer];
      if (current == null || m.createdAt >= current.createdAt) last[m.peer] = m;
    }
    return [
      for (final e in last.entries) Conversation(peer: e.key, last: e.value),
    ]..sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
  }

  /// Chats I accepted (or started).
  List<Conversation> get conversations =>
      _conversationsIn(ContactState.accepted);

  /// First contacts from unknown people, waiting for accept / refuse / block.
  List<Conversation> get requests => _conversationsIn(ContactState.pending);

  ContactState? stateOf(String peer) => _contacts[peer];
  bool isAccepted(String peer) => _contacts[peer] == ContactState.accepted;

  List<Message> messagesWith(String peer) =>
      _byId.values.where((m) => m.peer == peer).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
    // Identity gone (panic) or switched: drop everything held in memory.
    // No DB access here — the wipe is destroying it.
    _sub?.cancel();
    _sub = null;
    _byId.clear();
    _contacts.clear();
    _info.clear();
    _nicknames.clear();
    _seenWraps.clear();
    _loaded = false;
    _reassembler.clear();
    _images.clear();
    _heldImages.clear();
    _sendProgress.clear();
    _me = id;
    notifyListeners();
    if (id != null) unawaited(_start(id));
  }

  Future<void> _start(Identity id) async {
    final docs = await _db.listDocs(_collection);
    if (_me != id) return;
    final contactDocs = await _db.listDocs(_contactsCollection);
    if (_me != id) return;
    for (final d in docs) {
      final m = Message.fromJson(d);
      _byId[m.id] = m;
    }
    final infoDocs = await _db.listDocs(_infoCollection);
    if (_me != id) return;
    for (final d in infoDocs) {
      _info[d['id'] as String] = (
        alias: d['alias'] as String?,
        verified: d['verified'] == true,
      );
    }
    for (final d in contactDocs) {
      _contacts[d['id'] as String] = ContactState.values.byName(
        d['state'] as String,
      );
    }
    // Conversations from before contact tracking existed.
    final untracked = _byId.values
        .map((m) => m.peer)
        .toSet()
        .difference(_contacts.keys.toSet());
    for (final peer in untracked) {
      await _setContact(peer, deriveContactState(messagesWith(peer)), id);
    }
    _sub = _transport.incoming.listen(_onGiftWrap);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _onGiftWrap(Nip01Event wrap) async {
    final me = _me;
    // Same wrap from several relays/transports: decrypt once.
    if (me == null || !_seenWraps.add(wrap.id)) return;
    final Nip01Event rumor;
    try {
      rumor = await _unwrap(me: me, giftWrap: wrap);
    } on Nip17Exception {
      return; // Not for us, forged or tampered: drop silently.
    }
    if (_me != me) return;

    final fromMe = rumor.pubKey == me.publicKey;
    final peer = fromMe ? _pTag(rumor) : rumor.pubKey;
    if (peer == null || peer == me.publicKey) return;

    final state = _contacts[peer];
    if (!fromMe && state == ContactState.blocked) return;
    if (rumor.kind == GroupState.kindState ||
        rumor.kind == GroupState.kindLeave ||
        (rumor.kind == Nip17.kindChat && groupIdOf(rumor) != null)) {
      // Groups never create 1:1 contacts or requests.
      _groupRumors.add(rumor);
      return;
    }
    if (rumor.kind == ImageTransfer.kindChunk) {
      if (!fromMe) await _onChunk(peer, rumor, me);
      return;
    }
    final isImage = rumor.kind == ImageTransfer.kindHeader;
    if (rumor.kind != Nip17.kindChat && !isImage) {
      // Profile cards & co: authenticated (unwrap checked the author), from
      // a non-blocked peer. They never create a contact on their own.
      if (!fromMe) _otherRumors.add(rumor);
      return;
    }
    final header = isImage ? ImageHeader.fromRumor(rumor) : null;
    if (isImage && header == null) return;
    if (fromMe) {
      // Our own self-copy (e.g. after a restore): I wrote to them, so I had
      // accepted them.
      if (state != ContactState.accepted) {
        await _setContact(peer, ContactState.accepted, me);
      }
    } else if (state == null) {
      await _setContact(peer, ContactState.pending, me);
    }

    final existing = _byId[rumor.id];
    if (existing != null) {
      // Our own self-copy coming back proves a relay stored it.
      if (existing.fromMe && existing.status != MessageStatus.sent) {
        await _put(existing.copyWith(status: MessageStatus.sent), me);
      }
      return;
    }
    final message = Message(
      id: rumor.id,
      peer: peer,
      fromMe: fromMe,
      text: header == null ? rumor.content : '',
      createdAt: rumor.createdAt,
      status: fromMe
          ? MessageStatus.sent
          : (header == null ? MessageStatus.received : MessageStatus.receiving),
      image: header,
    );
    await _put(message, me);
    if (!fromMe && _me == me) _arrivals.add(message);
    if (header != null && !fromMe) {
      final bytes = _reassembler.addHeader(peer, header);
      if (bytes != null) await _imageComplete(message, bytes, me);
    }
  }

  Future<void> _onChunk(String peer, Nip01Event rumor, Identity me) async {
    final chunk = ImageChunk.fromRumor(rumor);
    if (chunk == null) return;
    final bytes = _reassembler.addChunk(peer, chunk);
    notifyListeners(); // progress
    if (bytes == null) return;
    final message = _byId.values
        .where((m) => m.peer == peer && m.image?.fileId == chunk.fileId)
        .firstOrNull;
    if (message != null) await _imageComplete(message, bytes, me);
  }

  /// Verified image in: stored encrypted if I accepted the sender, held in
  /// memory while their request is pending.
  Future<void> _imageComplete(
    Message message,
    Uint8List bytes,
    Identity me,
  ) async {
    final fileId = message.image!.fileId;
    if (isAccepted(message.peer)) {
      await _storeImage(fileId, bytes, me);
    } else {
      _heldImages[fileId] = bytes;
    }
    await _put(message.copyWith(status: MessageStatus.received), me);
  }

  Future<void> _storeImage(String fileId, Uint8List bytes, Identity me) async {
    if (_me != me) return;
    _images[fileId] = bytes;
    await _db.putDoc(_imagesCollection, {
      'id': fileId,
      'data': base64Encode(bytes),
    });
  }

  /// Image bytes for display. Null while incomplete, and for pending
  /// requests: nothing from a stranger is rendered before I accept them.
  Future<Uint8List?> imageFor(Message m) async {
    final fileId = m.image?.fileId;
    if (fileId == null) return null;
    if (!m.fromMe && !isAccepted(m.peer)) return null;
    final cached = _images[fileId];
    if (cached != null) return cached;
    final doc = await _db.getDoc(_imagesCollection, fileId);
    final data = doc?['data'];
    if (data is! String) return null;
    return _images[fileId] = base64Decode(data);
  }

  /// (done, total) chunks for an image being sent or received.
  (int, int)? imageProgress(Message m) {
    final image = m.image;
    if (image == null) return null;
    if (m.fromMe) return _sendProgress[m.id];
    if (m.status != MessageStatus.receiving) return null;
    return _reassembler.progress(m.peer, image.fileId) ?? (0, image.chunks);
  }

  /// Decodes, strips all metadata and resizes — what the preview shows is
  /// exactly what will be sent. Throws on unusable images.
  Future<({Uint8List bytes, int width, int height})> prepareImage(
    Uint8List raw,
  ) => _anonymize(raw);

  Future<void> sendImage(
    String peer,
    ({Uint8List bytes, int width, int height}) prepared,
  ) async {
    final me = _me;
    if (me == null) return;
    final bytes = prepared.bytes;
    final header = ImageHeader(
      fileId: ImageTransfer.newFileId(),
      sha256: ImageTransfer.sha256Hex(bytes),
      size: bytes.length,
      chunks: ImageTransfer.split(bytes).length,
      width: prepared.width,
      height: prepared.height,
    );
    final rumor = ImageTransfer.headerRumor(
      sender: me.publicKey,
      recipient: peer,
      header: header,
    );
    final message = Message(
      id: rumor.id,
      peer: peer,
      fromMe: true,
      text: '',
      createdAt: rumor.createdAt,
      status: MessageStatus.sending,
      image: header,
    );
    if (_contacts[peer] != ContactState.accepted) {
      await _setContact(peer, ContactState.accepted, me);
    }
    await _storeImage(header.fileId, bytes, me);
    await _put(message, me);
    await _deliverImage(message, rumor, bytes, me);
  }

  Future<void> _deliverImage(
    Message m,
    Nip01Event headerRumor,
    Uint8List bytes,
    Identity me,
  ) async {
    final chunks = ImageTransfer.split(bytes);
    try {
      await _transport.deliver(
        await _wrap(sender: me, recipientPubkey: m.peer, rumor: headerRumor),
      );
      for (var i = 0; i < chunks.length; i++) {
        if (i > 0 && chunkPacing > Duration.zero) {
          await Future<void>.delayed(chunkPacing);
        }
        final rumor = ImageTransfer.chunkRumor(
          sender: me.publicKey,
          recipient: m.peer,
          fileId: m.image!.fileId,
          index: i,
          data: chunks[i],
        );
        await _transport.deliver(
          await _wrap(sender: me, recipientPubkey: m.peer, rumor: rumor),
        );
        _sendProgress[m.id] = (i + 1, chunks.length);
        notifyListeners();
      }
      _sendProgress.remove(m.id);
      await _put(m.copyWith(status: MessageStatus.sent), me);
    } catch (_) {
      _sendProgress.remove(m.id);
      await _put(m.copyWith(status: MessageStatus.failed), me);
    }
    // No self-copies for images: ~20 extra events each; a restored account
    // shows past images as unavailable.
  }

  Future<void> send(String peer, String text) async {
    final me = _me;
    final trimmed = text.trim();
    if (me == null || trimmed.isEmpty) return;
    final rumor = Nip17.chatRumor(
      senderPubkey: me.publicKey,
      recipientPubkey: peer,
      text: trimmed,
    );
    final message = Message(
      id: rumor.id,
      peer: peer,
      fromMe: true,
      text: trimmed,
      createdAt: rumor.createdAt,
      status: MessageStatus.sending,
    );
    // Writing to someone is accepting them (also unblocks).
    if (_contacts[peer] != ContactState.accepted) {
      await _setContact(peer, ContactState.accepted, me);
    }
    await _put(message, me);
    await _deliver(message, rumor, me);
  }

  /// Resends messages that never made it (e.g. when relays come back).
  Future<void> retryFailed() async {
    final me = _me;
    if (me == null) return;
    final pending = _byId.values
        .where((m) => m.fromMe && m.status != MessageStatus.sent)
        .toList();
    for (final m in pending) {
      await retry(m.id);
    }
  }

  Future<void> retry(String id) async {
    final me = _me;
    final m = _byId[id];
    if (me == null || m == null || !m.fromMe) return;
    final image = m.image;
    if (image != null) {
      final bytes = await imageFor(m);
      if (bytes == null) return;
      final rumor = ImageTransfer.headerRumor(
        sender: me.publicKey,
        recipient: m.peer,
        header: image,
        createdAt: m.createdAt,
      );
      await _put(m.copyWith(status: MessageStatus.sending), me);
      await _deliverImage(m, rumor, bytes, me);
      return;
    }
    // Rebuilding with the stored timestamp gives back the same rumor id, so
    // the recipient dedupes if an earlier attempt did arrive.
    final rumor = Nip17.chatRumor(
      senderPubkey: me.publicKey,
      recipientPubkey: m.peer,
      text: m.text,
      createdAt: m.createdAt,
    );
    await _put(m.copyWith(status: MessageStatus.sending), me);
    await _deliver(m, rumor, me);
  }

  Future<void> _deliver(Message m, Nip01Event rumor, Identity me) async {
    try {
      final forPeer = await _wrap(
        sender: me,
        recipientPubkey: m.peer,
        rumor: rumor,
      );
      await _transport.deliver(forPeer);
      await _put(m.copyWith(status: MessageStatus.sent), me);
    } catch (_) {
      await _put(m.copyWith(status: MessageStatus.failed), me);
      return;
    }
    // Self-copy (NIP-17): lets a restored account get its sent messages
    // back. Best effort — the message is already delivered.
    try {
      final forMe = await _wrap(
        sender: me,
        recipientPubkey: me.publicKey,
        rumor: rumor,
      );
      _seenWraps.add(forMe.id);
      await _transport.deliver(forMe);
    } catch (_) {}
  }

  Future<void> accept(String peer) async {
    final me = _me;
    if (me == null) return;
    await _setContact(peer, ContactState.accepted, me);
    // Images received while pending were only held in memory.
    for (final m in messagesWith(peer)) {
      final held = _heldImages.remove(m.image?.fileId);
      if (held != null) await _storeImage(m.image!.fileId, held, me);
    }
    notifyListeners();
  }

  /// Deletes the request and its messages. No signal goes back to the sender;
  /// a later message from them shows up as a new request.
  Future<void> refuse(String peer) async {
    final me = _me;
    if (me == null) return;
    await _deleteConversation(peer, me);
    _contacts.remove(peer);
    notifyListeners();
    await _db.deleteDoc(_contactsCollection, peer);
  }

  /// Deletes the conversation and drops everything this peer sends from now
  /// on, before it is stored.
  Future<void> block(String peer) async {
    final me = _me;
    if (me == null) return;
    await _deleteConversation(peer, me);
    await _setContact(peer, ContactState.blocked, me);
  }

  /// Local nickname (never sent anywhere). Empty/null clears it.
  Future<void> setAlias(String peer, String? alias) async {
    final me = _me;
    if (me == null) return;
    final trimmed = alias?.trim();
    await _putInfo(
      peer,
      alias: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      verified: isVerified(peer),
      owner: me,
    );
  }

  /// "I compared the safety number with them out of band."
  Future<void> setVerified(String peer, bool verified) async {
    final me = _me;
    if (me == null) return;
    await _putInfo(peer, alias: aliasOf(peer), verified: verified, owner: me);
  }

  Future<void> _putInfo(
    String peer, {
    required String? alias,
    required bool verified,
    required Identity owner,
  }) async {
    if (_me != owner) return;
    _info[peer] = (alias: alias, verified: verified);
    notifyListeners();
    await _db.putDoc(_infoCollection, {
      'id': peer,
      'alias': alias,
      'verified': verified,
    });
  }

  /// Forgets the block: their next message arrives as a new request.
  Future<void> unblock(String peer) async {
    final me = _me;
    if (me == null || _contacts[peer] != ContactState.blocked) return;
    _contacts.remove(peer);
    notifyListeners();
    await _db.deleteDoc(_contactsCollection, peer);
  }

  Future<void> _deleteConversation(String peer, Identity owner) async {
    if (_info.remove(peer) != null) {
      unawaited(_db.deleteDoc(_infoCollection, peer));
    }
    final ids = _byId.values
        .where((m) => m.peer == peer)
        .map((m) => m.id)
        .toList();
    final fileIds = <String>[];
    for (final id in ids) {
      final fileId = _byId.remove(id)?.image?.fileId;
      if (fileId != null) {
        fileIds.add(fileId);
        _images.remove(fileId);
        _heldImages.remove(fileId);
      }
    }
    notifyListeners();
    for (final id in ids) {
      if (_me != owner) return;
      await _db.deleteDoc(_collection, id);
    }
    for (final fileId in fileIds) {
      if (_me != owner) return;
      await _db.deleteDoc(_imagesCollection, fileId);
    }
  }

  Future<void> _setContact(
    String peer,
    ContactState state,
    Identity owner,
  ) async {
    if (_me != owner) return;
    _contacts[peer] = state;
    notifyListeners();
    await _db.putDoc(_contactsCollection, {'id': peer, 'state': state.name});
  }

  Future<void> _put(Message m, Identity owner) async {
    // Late completions after a wipe or identity switch must not write: that
    // would resurrect a database the panic button just destroyed.
    if (_me != owner) return;
    _byId[m.id] = m;
    notifyListeners();
    await _db.putDoc(_collection, m.toJson(), updatedAt: m.createdAt * 1000);
  }

  static String? _pTag(Nip01Event e) {
    for (final t in e.tags) {
      if (t.length > 1 && t[0] == 'p') return t[1];
    }
    return null;
  }

  @override
  void dispose() {
    _identity.removeListener(_syncWithIdentity);
    _sub?.cancel();
    _otherRumors.close();
    _groupRumors.close();
    _arrivals.close();
    super.dispose();
  }
}
