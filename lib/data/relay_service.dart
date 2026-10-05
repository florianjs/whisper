import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import '../logic/identity.dart';
import '../logic/relays.dart';
import '../logic/transport.dart';
import 'db.dart';
import 'identity_store.dart';

/// The slice of a Nostr client [RelayService] needs. Abstract so the service
/// is testable without sockets.
abstract class RelayBackend {
  /// Emits `url → connected` whenever a relay connects or drops.
  Stream<Map<String, bool>> get connectivity;
  Future<void> reconnect();
  Future<void> publish({
    required int kind,
    required List<List<String>> tags,
    required String content,
  });

  /// Publishes an already signed event (gift wraps are signed by one-time
  /// keys). [relays] null means our own relays.
  Future<void> publishSigned(Nip01Event event, {List<String>? relays});

  /// Live gift wraps p-tagged to [pubkey] since [since] (unix seconds).
  Stream<Nip01Event> giftWraps({required String pubkey, required int since});

  /// The NIP-17 inbox relays (kind 10050) [pubkey] advertises, newest list.
  Future<List<String>> inboxRelaysOf(String pubkey);

  Future<void> dispose();
}

typedef RelayBackendFactory =
    RelayBackend Function(Identity identity, List<String> relays);

class NdkRelayBackend implements RelayBackend {
  NdkRelayBackend(Identity identity, List<String> relays)
    : _relays = relays,
      _ndk = Ndk(
        NdkConfig(
          // Memory only: nothing Nostr-related may reach disk outside the
          // SQLCipher database.
          cache: MemCacheManager(),
          eventVerifier: Bip340EventVerifier(),
          // Always our list: an empty one makes ndk fall back to its own
          // bootstrap relays, including a profile aggregator.
          bootstrapRelays: relays,
          // ndk prints to stdout, i.e. logcat, readable over adb.
          logLevel: LogLevel.off,
          // Default UA names the library and its version to every relay.
          userAgent: 'nostr-client',
        ),
      ) {
    _ndk.accounts.loginPrivateKey(
      pubkey: identity.publicKey,
      privkey: identity.privateKey,
    );
  }

  final Ndk _ndk;
  final List<String> _relays;

  @override
  Stream<Map<String, bool>> get connectivity => _ndk
      .connectivity
      .relayConnectivityChanges
      .map((list) => {for (final r in list) r.url: r.isConnected});

  @override
  Future<void> reconnect() => _ndk.connectivity.tryReconnect();

  @override
  Future<void> publish({
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {
    final pubkey = _ndk.accounts.getPublicKey();
    if (pubkey == null) throw StateError('not logged in');
    final response = _ndk.broadcast.broadcast(
      nostrEvent: Nip01Event(
        pubKey: pubkey,
        kind: kind,
        tags: tags,
        content: content,
      ),
    );
    final results = await response.broadcastDoneFuture;
    if (!results.any((r) => r.broadcastSuccessful)) {
      throw StateError('no relay accepted the event');
    }
  }

  @override
  Future<void> publishSigned(Nip01Event event, {List<String>? relays}) async {
    final response = _ndk.broadcast.broadcast(
      nostrEvent: event,
      specificRelays: relays ?? _relays,
    );
    final results = await response.broadcastDoneFuture;
    if (!results.any((r) => r.broadcastSuccessful)) {
      throw StateError('no relay accepted the event');
    }
  }

  @override
  Stream<Nip01Event> giftWraps({required String pubkey, required int since}) {
    final account = _ndk.accounts.getLoggedAccount();
    final response = _ndk.requests.subscription(
      filter: Filter(kinds: const [1059], pTags: [pubkey], since: since),
      explicitRelays: _relays,
      // NIP-42: DM-protecting relays only hand gift wraps to their recipient.
      authenticateAs: account == null ? null : [account],
    );
    final controller = StreamController<Nip01Event>();
    StreamSubscription<Nip01Event>? inner;
    controller.onListen = () {
      inner = response.stream.listen(
        controller.add,
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await inner?.cancel();
      await _ndk.requests.closeSubscription(response.requestId);
    };
    return controller.stream;
  }

  @override
  Future<List<String>> inboxRelaysOf(String pubkey) async {
    final events = await _ndk.requests
        .query(
          filter: Filter(kinds: const [10050], authors: [pubkey], limit: 1),
          explicitRelays: _relays,
          timeout: const Duration(seconds: 8),
        )
        .future;
    if (events.isEmpty) return const [];
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final t in events.first.tags)
        if (t.length > 1 && t[0] == 'relay') ?normalizeRelayUrl(t[1]),
    ];
  }

  @override
  Future<void> dispose() async {
    _ndk.accounts.logout();
    await _ndk.destroy();
    // ndk keeps relay state in a static shared by every instance; clear it
    // so the next identity (e.g. after the panic button) starts clean.
    _ndk.relays.globalState.relays.clear();
    _ndk.relays.globalState.blockedRelays.clear();
  }
}

/// What [RelayService] needs while the app lock holds: no account, nothing
/// to sign or decrypt with — only the public key every sender already knows.
abstract class WatchBackend {
  Stream<Map<String, bool>> get connectivity;
  Future<void> reconnect();

  /// Gift wraps p-tagged to [pubkey] reaching the relays from now on: none
  /// of what they already hold (a gift wrap's date is randomized up to two
  /// days back, so `since` can't tell new from old).
  Stream<Nip01Event> newGiftWraps(String pubkey);
  Future<void> dispose();
}

typedef WatchBackendFactory = WatchBackend Function(List<String> relays);

class NdkWatchBackend implements WatchBackend {
  NdkWatchBackend(List<String> relays)
    : _relays = relays,
      _ndk = Ndk(
        NdkConfig(
          cache: MemCacheManager(),
          eventVerifier: Bip340EventVerifier(),
          bootstrapRelays: relays,
          logLevel: LogLevel.off,
          userAgent: 'nostr-client',
        ),
      );

  final Ndk _ndk;
  final List<String> _relays;

  @override
  Stream<Map<String, bool>> get connectivity => _ndk
      .connectivity
      .relayConnectivityChanges
      .map((list) => {for (final r in list) r.url: r.isConnected});

  @override
  Future<void> reconnect() => _ndk.connectivity.tryReconnect();

  @override
  Stream<Nip01Event> newGiftWraps(String pubkey) {
    final response = _ndk.requests.subscription(
      // limit 0: no stored events, only live ones.
      filter: Filter(kinds: const [1059], pTags: [pubkey], limit: 0),
      explicitRelays: _relays,
    );
    final controller = StreamController<Nip01Event>();
    StreamSubscription<Nip01Event>? inner;
    controller.onListen = () {
      inner = response.stream.listen(
        controller.add,
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await inner?.cancel();
      await _ndk.requests.closeSubscription(response.requestId);
    };
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _ndk.destroy();
    _ndk.relays.globalState.relays.clear();
    _ndk.relays.globalState.blockedRelays.clear();
  }
}

/// Keeps the app connected to its relays while an identity exists, and
/// carries gift wraps over them.
class RelayService extends ChangeNotifier implements Transport {
  RelayService({
    required IdentityStore identity,
    required DocStore db,
    RelayBackendFactory? backendFactory,
    WatchBackendFactory? watchFactory,
    Random? random,
    this.settleTimeout = const Duration(seconds: 10),
    this.resubscribeDebounce = const Duration(seconds: 2),
    this.downtimeTick = const Duration(minutes: 10),
  }) : _identity = identity,
       _db = db,
       _factory = backendFactory ?? NdkRelayBackend.new,
       _watchFactory = watchFactory ?? NdkWatchBackend.new,
       _random = random ?? Random() {
    _identity.addListener(_syncWithIdentity);
    _syncWithIdentity();
  }

  /// NIP-17 "DM relays" list: tells senders where to deliver our messages.
  static const inboxRelaysKind = 10050;

  final IdentityStore _identity;
  final DocStore _db;
  final RelayBackendFactory _factory;
  final WatchBackendFactory _watchFactory;
  final Random _random;
  final Duration settleTimeout;

  /// Groups relays connecting one after another into one resubscription.
  final Duration resubscribeDebounce;

  /// How often relay downtime is counted. Only ticks that actually fire
  /// count: time spent with the app suspended is never held against a relay.
  final Duration downtimeTick;

  RelayBackend? _backend;
  String? _backendPubkey;
  StreamSubscription<Map<String, bool>>? _sub;
  Timer? _retryTimer;
  Timer? _settleTimer;
  int _attempt = 0;
  bool _settled = false;
  bool _inboxPublished = false;

  final _incoming = StreamController<Nip01Event>.broadcast();
  StreamSubscription<Nip01Event>? _wrapsSub;
  final Map<String, (DateTime, List<String>)> _inboxCache = {};

  /// Gift wraps are backdated up to 2 days, so a resubscription has to reach
  /// that far behind the last moment we were known to be listening.
  static const _backdateWindow = Duration(days: 2, hours: 1);

  /// Standby relays, in order of use (see [failover]).
  List<String> _spares = spareRelays;

  /// False once the user edited the list: their choice, never auto-replaced.
  bool _autoRelays = true;
  Map<String, Duration> _downtime = {};
  Timer? _downtimeTimer;

  Map<String, bool> _relays = const {};
  Map<String, bool> get relays => _relays;
  RelayHealth get health => healthOf(_relays, settled: _settled);
  int get connectedCount => _relays.values.where((c) => c).length;

  void _syncWithIdentity() {
    final id = _identity.identity;
    if (id == null) {
      _stop();
      final watch = _watch;
      if (watch != null && _watchBackend == null) unawaited(_startWatch(watch));
    } else if (_backendPubkey != id.publicKey) {
      stopWatching();
      _stop();
      _start(id);
    }
  }

  /// Completes once the last backend is torn down. ndk keeps connections in
  /// a static shared by every instance, and destroying one closes them all:
  /// a new backend must not connect before the old one is gone.
  Future<void> _closing = Future.value();
  int _closesPending = 0;

  void _close(Future<void> Function() dispose) {
    _closesPending++;
    _closing = _closing
        .then((_) => dispose())
        .timeout(const Duration(seconds: 10))
        .catchError((Object _) {})
        .whenComplete(() => _closesPending--);
  }

  // --- Watching while locked ----------------------------------------------

  (String, List<String>)? _watch;
  WatchBackend? _watchBackend;
  StreamSubscription<Map<String, bool>>? _watchConn;
  StreamSubscription<Nip01Event>? _watchSub;
  Timer? _watchRetry;
  int _watchAttempt = 0;
  Set<String> _watchConnected = {};
  Set<String> _watchSubscribedOn = {};
  final _seenSealed = <String>{};
  final _sealed = StreamController<String>.broadcast();

  /// Gift wrap ids reaching our inbox while the app is locked. Sealed: the
  /// key to open them is gone from memory.
  Stream<String> get sealedArrivals => _sealed.stream;

  /// True from [watchInbox] until [stopWatching].
  bool get watching => _watch != null;

  /// Call right before the identity is forgotten (app lock): keeps listening
  /// for gift wraps to our public key, without the account key. Memory only.
  void watchInbox() {
    final pubkey = _backendPubkey;
    if (pubkey == null || _relays.isEmpty) return;
    _watch = (pubkey, _relays.keys.toList());
    notifyListeners();
  }

  void stopWatching() {
    if (_watch == null) return;
    _watch = null;
    _watchRetry?.cancel();
    _watchConn?.cancel();
    _watchConn = null;
    _watchSub?.cancel();
    _watchSub = null;
    _watchConnected = {};
    _watchSubscribedOn = {};
    _seenSealed.clear();
    final backend = _watchBackend;
    _watchBackend = null;
    if (backend != null) _close(backend.dispose);
    notifyListeners();
  }

  Future<void> _startWatch((String, List<String>) watch) async {
    if (_closesPending > 0) await _closing;
    if (_watch != watch || _watchBackend != null || _backend != null) return;
    final backend = _watchFactory(watch.$2);
    _watchBackend = backend;
    _watchAttempt = 0;
    _watchConn = backend.connectivity.listen((update) {
      _watchConnected = {
        ..._watchConnected.where((u) => update[u] != false),
        for (final e in update.entries)
          if (e.value && watch.$2.contains(e.key)) e.key,
      };
      _watchSubscribedOn = _watchSubscribedOn.intersection(_watchConnected);
      if (_watchConnected.difference(_watchSubscribedOn).isNotEmpty) {
        _watchSubscribe(backend, watch.$1);
      }
      if (_watchConnected.isEmpty) {
        _watchRetryLater(backend);
      } else {
        _watchAttempt = 0;
        _watchRetry?.cancel();
      }
    });
    _watchSubscribe(backend, watch.$1);
    _watchRetryLater(backend);
  }

  /// Same as [_subscribe]: a REQ isn't replayed to relays that connect
  /// later. limit 0 makes a new one free: nothing old comes back.
  void _watchSubscribe(WatchBackend backend, String pubkey) {
    unawaited(_watchSub?.cancel());
    _watchSubscribedOn = {..._watchConnected};
    _watchSub = backend
        .newGiftWraps(pubkey)
        .listen(
          (w) {
            if (_watchBackend == backend && _seenSealed.add(w.id)) {
              _sealed.add(w.id);
            }
          },
          onError: (Object e) {
            if (kDebugMode) debugPrint('WHISPER_RELAY watch error $e');
          },
        );
  }

  void _watchRetryLater(WatchBackend backend) {
    if (_watchRetry?.isActive ?? false) return;
    _watchRetry = Timer(retryDelay(_watchAttempt++, random: _random), () async {
      if (_watchBackend != backend || _watchConnected.isNotEmpty) return;
      await backend.reconnect();
      if (_watchBackend == backend && _watchConnected.isEmpty) {
        _watchRetryLater(backend);
      }
    });
  }

  /// A saved list without `auto` was written by the user's relay editor.
  Future<List<String>> _loadRelayUrls() async {
    final doc = await _db.getDoc('settings', 'relays');
    final urls = (doc?['urls'] as List?)?.cast<String>();
    final saved = urls != null && urls.isNotEmpty;
    _autoRelays = !saved || doc?['auto'] == true;
    _spares = (doc?['spares'] as List?)?.cast<String>() ?? spareRelays;
    return saved ? urls : defaultRelays;
  }

  Future<void> _start(Identity id) async {
    _backendPubkey = id.publicKey;
    final urls = await _loadRelayUrls();
    final downtime = await _db.getDoc('meta', 'relay_downtime');
    if (_closesPending > 0) await _closing;
    // Identity changed or was wiped while loading.
    if (_backendPubkey != id.publicKey) return;
    _downtime = {
      for (final u in urls)
        if (downtime?[u] case final int seconds) u: Duration(seconds: seconds),
    };

    final backend = _factory(id, urls);
    _backend = backend;
    _relays = {for (final u in urls) u: false};
    _settled = false;
    _attempt = 0;
    _inboxPublished = false;
    _sub = backend.connectivity.listen(_onConnectivity);
    _settleTimer = Timer(settleTimeout, _onSettled);
    notifyListeners();

    await _subscribe(backend, id.publicKey);
  }

  /// Relays the current gift-wrap subscription was opened on.
  Set<String> _subscribedOn = {};
  Timer? _resubscribe;

  /// (Re)opens the inbox subscription on the relays connected right now.
  /// A subscription made while no relay was reachable (Tor still
  /// bootstrapping, phone offline at launch) is never replayed to relays
  /// that connect later — so it's recreated whenever new relays come up.
  /// Duplicates are harmless: messages are deduped by id.
  Future<void> _subscribe(RelayBackend backend, String pubkey) async {
    final since = await _inboxSince();
    if (_backend != backend) return;
    // No need to wait for the old REQ to be closed before opening the new.
    unawaited(_wrapsSub?.cancel());
    _subscribedOn = {
      for (final e in _relays.entries)
        if (e.value) e.key,
    };
    if (kDebugMode) {
      debugPrint(
        'WHISPER_RELAY subscribe on ${_subscribedOn.length} relays, '
        'since -${DateTime.now().millisecondsSinceEpoch ~/ 1000 - since}s',
      );
    }
    _wrapsSub = backend
        .giftWraps(pubkey: pubkey, since: since)
        .listen(
          (w) {
            if (kDebugMode) debugPrint('WHISPER_RELAY wrap in');
            _incoming.add(w);
          },
          onError: (Object e) {
            if (kDebugMode) debugPrint('WHISPER_RELAY sub error $e');
          },
        );
  }

  void _maybeResubscribe() {
    final backend = _backend;
    final pubkey = _backendPubkey;
    if (backend == null || pubkey == null) return;
    final connected = {
      for (final e in _relays.entries)
        if (e.value) e.key,
    };
    // Forget relays that dropped: when they come back they need the REQ again.
    _subscribedOn = _subscribedOn.intersection(connected);
    if (connected.difference(_subscribedOn).isEmpty) return;
    _resubscribe?.cancel();
    _resubscribe = Timer(resubscribeDebounce, () {
      if (_backend == backend) unawaited(_subscribe(backend, pubkey));
    });
  }

  /// First sync of an account (new or restored) fetches everything relays
  /// still hold; afterwards only what could have arrived since last time.
  Future<int> _inboxSince() async {
    final doc = await _db.getDoc('meta', 'inbox_sync');
    final listening = doc?['listeningAt'] as int?;
    if (listening == null) return 0;
    final from = DateTime.fromMillisecondsSinceEpoch(listening * 1000);
    return from.subtract(_backdateWindow).millisecondsSinceEpoch ~/ 1000;
  }

  /// "We had a live subscription at this time": anything sent after it is
  /// either received already or backdated no earlier than 2 days before it.
  Future<void> _markListening() async {
    if (_backend == null || connectedCount == 0) return;
    await _db.putDoc('meta', {
      'id': 'inbox_sync',
      'listeningAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  @override
  Stream<Nip01Event> get incoming => _incoming.stream;

  @override
  Future<void> deliver(Nip01Event giftWrap) async {
    final backend = _backend;
    final me = _backendPubkey;
    if (backend == null || me == null) throw StateError('offline');
    final recipient = giftWrap.tags
        .firstWhere((t) => t.length > 1 && t[0] == 'p')
        .elementAt(1);
    if (recipient == me) {
      await backend.publishSigned(giftWrap);
      return;
    }
    final inbox = await _inboxRelaysOf(backend, recipient);
    try {
      // No published inbox: fall back to our relays, which most clients read.
      await backend.publishSigned(
        giftWrap,
        relays: inbox.isEmpty ? null : inbox,
      );
    } catch (_) {
      // Their relays may have died and been swapped for spares since we
      // learnt them: look again, past the cache, and retry once if it moved.
      final fresh = await _inboxRelaysOf(backend, recipient, fresh: true);
      if (_backend != backend || listEquals(fresh, inbox)) rethrow;
      await backend.publishSigned(
        giftWrap,
        relays: fresh.isEmpty ? null : fresh,
      );
    }
  }

  /// Inbox relays learnt from a contact's QR code / invite: lets the first
  /// message reach them without looking them up on a relay (which could be
  /// blocked or not have their list).
  void rememberInboxRelays(String pubkey, List<String> relays) {
    if (relays.isEmpty) return;
    _inboxHints[pubkey] = relays;
  }

  final Map<String, List<String>> _inboxHints = {};

  /// The contact's published inbox wins over the QR/invite hint: they may
  /// have moved to spare relays since the code was scanned. The hint still
  /// answers right away the first time, and whenever no list can be found.
  Future<List<String>> _inboxRelaysOf(
    RelayBackend b,
    String pubkey, {
    bool fresh = false,
  }) async {
    final hint = _inboxHints[pubkey];
    final cached = _inboxCache[pubkey];
    if (!fresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(hours: 1)) {
      return cached.$2.isEmpty ? (hint ?? const []) : cached.$2;
    }
    if (!fresh && cached == null && hint != null) {
      unawaited(_lookUpInbox(b, pubkey));
      return hint;
    }
    final found = await _lookUpInbox(b, pubkey) ?? cached?.$2 ?? const [];
    return found.isEmpty ? (hint ?? const []) : found;
  }

  /// Null when the lookup failed (as opposed to "no list published").
  Future<List<String>?> _lookUpInbox(RelayBackend b, String pubkey) async {
    try {
      final relays = await b.inboxRelaysOf(pubkey);
      if (_backend == b) _inboxCache[pubkey] = (DateTime.now(), relays);
      return relays;
    } catch (_) {
      return null;
    }
  }

  // Never writes to the DB: _stop runs during the panic wipe, and a late
  // write would recreate a database (and a key) right after destroying them.
  void _stop() {
    _resubscribe?.cancel();
    _subscribedOn = {};
    _wrapsSub?.cancel();
    _wrapsSub = null;
    _inboxCache.clear();
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    _downtimeTimer?.cancel();
    _downtimeTimer = null;
    _sub?.cancel();
    _sub = null;
    final backend = _backend;
    _backend = null;
    _backendPubkey = null;
    if (backend != null) _close(backend.dispose);
    if (_relays.isNotEmpty) {
      _relays = const {};
      notifyListeners();
    }
  }

  void _onConnectivity(Map<String, bool> update) {
    // Only our relays count, whatever else ndk may report.
    _relays = {
      ..._relays,
      for (final e in update.entries)
        if (_relays.containsKey(e.key)) e.key: e.value,
    };
    _maybeResubscribe();
    // A relay back up starts over, even if no tick runs before it drops again.
    final back = _downtime.keys.where((u) => _relays[u] == true).toList();
    if (back.isNotEmpty) {
      _downtime = {..._downtime}..removeWhere((u, _) => back.contains(u));
      unawaited(_saveDowntime());
    }
    _syncDowntimeTimer();
    if (connectedCount > 0) {
      _settleTimer?.cancel();
      _settled = true;
      _attempt = 0;
      _retryTimer?.cancel();
      unawaited(_publishInboxRelays());
      unawaited(_markListening());
    } else if (_settled) {
      _scheduleRetry();
    }
    notifyListeners();
  }

  void _onSettled() {
    if (_settled) return;
    _settled = true;
    if (connectedCount == 0) _scheduleRetry();
    notifyListeners();
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(retryDelay(_attempt++, random: _random), () async {
      final backend = _backend;
      if (backend == null || connectedCount > 0) return;
      await backend.reconnect();
      if (_backend == backend && connectedCount == 0) _scheduleRetry();
    });
  }

  /// Replaces the relay list (user's choice: never auto-replaced afterwards)
  /// and reconnects with it.
  Future<void> setRelays(List<String> urls) async {
    await _db.putDoc('settings', {'id': 'relays', 'urls': urls});
    await _db.deleteDoc('meta', 'relay_downtime');
    await _restart();
  }

  Future<void> _restart() async {
    final id = _identity.identity;
    if (id == null) return;
    _stop();
    await _start(id);
  }

  /// Ticks only while some relays are up and others down: all up, nothing
  /// to count; all down, we are the ones offline. No wakeups otherwise.
  void _syncDowntimeTimer() {
    final want = connectedCount > 0 && connectedCount < _relays.length;
    if (want == (_downtimeTimer != null)) return;
    _downtimeTimer?.cancel();
    _downtimeTimer = want
        ? Timer.periodic(downtimeTick, (_) => _onDowntimeTick())
        : null;
  }

  /// Counts relay downtime and, on the default list, swaps relays dead for
  /// [deadRelayAfter] for spares. The new list is then published as our
  /// inbox (kind 10050) on the next connection, so senders follow.
  Future<void> _onDowntimeTick() async {
    final backend = _backend;
    if (backend == null) return;
    final before = _downtime;
    _downtime = accrueDowntime(_downtime, _relays, downtimeTick);
    final swap = _autoRelays
        ? failover(
            relays: _relays.keys.toList(),
            spares: _spares,
            downtime: _downtime,
          )
        : null;
    if (swap != null) {
      if (kDebugMode) debugPrint('WHISPER_RELAY failover → ${swap.relays}');
      await _db.putDoc('settings', {
        'id': 'relays',
        'urls': swap.relays,
        'spares': swap.spares,
        'auto': true,
      });
      // Wiped meanwhile: a late write would recreate the database.
      if (_backend != backend) return;
      await _db.deleteDoc('meta', 'relay_downtime');
      if (_backend == backend) await _restart();
      return;
    }
    if (mapEquals(before, _downtime) || _backend != backend) return;
    await _saveDowntime();
  }

  Future<void> _saveDowntime() async {
    if (_backend == null) return;
    await _db.putDoc('meta', {
      'id': 'relay_downtime',
      for (final e in _downtime.entries) e.key: e.value.inSeconds,
    });
  }

  /// Immediate retry, e.g. when the app returns to the foreground: waiting for
  /// the backoff timer after the user opens the app feels broken.
  Future<void> reconnectNow() async {
    final backend = _backend;
    if (backend == null || connectedCount == _relays.length) return;
    _retryTimer?.cancel();
    _attempt = 0;
    await backend.reconnect();
    if (_backend == backend && connectedCount == 0) _scheduleRetry();
  }

  /// NIP-62 request to vanish, to every relay (`ALL_RELAYS`): delete all
  /// our events and the gift wraps addressed to us. Throws if no relay
  /// accepted it or none is connected.
  Future<void> requestVanish() async {
    final backend = _backend;
    if (backend == null || connectedCount == 0) throw StateError('offline');
    await backend.publish(
      kind: vanishKind,
      tags: const [
        ['relay', 'ALL_RELAYS'],
      ],
      content: '',
    );
  }

  static const vanishKind = 62;

  /// Publishes our inbox relay list once per relay set. Remembered in the
  /// encrypted DB so it isn't re-sent (and re-timestamped) on every launch.
  Future<void> _publishInboxRelays() async {
    final backend = _backend;
    if (backend == null || _inboxPublished) return;
    _inboxPublished = true;
    final urls = _relays.keys.toList()..sort();
    final done = await _db.getDoc('meta', 'inbox_relays');
    if (listEquals((done?['urls'] as List?)?.cast<String>(), urls)) return;
    try {
      await backend.publish(
        kind: inboxRelaysKind,
        tags: [
          for (final u in urls) ['relay', u],
        ],
        content: '',
      );
      if (_backend != backend) return;
      await _db.putDoc('meta', {'id': 'inbox_relays', 'urls': urls});
    } catch (_) {
      // Retried on the next reconnect.
      _inboxPublished = false;
    }
  }

  @override
  void dispose() {
    _identity.removeListener(_syncWithIdentity);
    stopWatching();
    _stop();
    _incoming.close();
    _sealed.close();
    super.dispose();
  }
}
