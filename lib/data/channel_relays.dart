import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ndk/ndk.dart' show Nip01Event, Nip01EventModel;

import '../logic/channel.dart';
import '../logic/relays.dart';
import '../logic/transport.dart';

/// Channel traffic on its own relay connections, apart from ndk's (which
/// carry the identity's inbox subscription). Given an HTTP client with its
/// own Tor isolation, a relay sees the inbox and the channel subscriptions
/// arrive from different circuits: it can't tell which identity follows
/// which channel.
///
/// A deliberately small NIP-01 client: REQ / CLOSE / EVENT / OK. Events are
/// verified by the ChannelStore, not here.
class ChannelRelayPool implements ChannelTransport {
  ChannelRelayPool({
    required List<String> Function() relays,
    HttpClient Function()? httpClient,
    Random? random,
    this.publishTimeout = const Duration(seconds: 15),
  }) : _ourRelays = relays,
       _httpClient = httpClient ?? HttpClient.new,
       _random = random ?? Random();

  final List<String> Function() _ourRelays;
  final HttpClient Function() _httpClient;
  final Random _random;
  final Duration publishTimeout;

  final _events = StreamController<Nip01Event>.broadcast();
  final Map<String, _Conn> _conns = {};
  Set<String> _watched = const {};
  Set<String> _probes = const {};
  List<String> _extra = const [];
  bool _disposed = false;

  static const _subId = 'ch';

  @override
  Stream<Nip01Event> get channelEvents => _events.stream;

  /// Relays currently connected (for tests and diagnostics).
  Iterable<String> get connected =>
      _conns.entries.where((e) => e.value.socket != null).map((e) => e.key);

  @override
  void watchChannels(
    Set<String> channelPks, {
    List<String> relays = const [],
    Set<String> probes = const {},
  }) {
    _watched = {...channelPks};
    _probes = probes.difference(_watched);
    _extra = [...relays];
    _sync();
  }

  /// Our relay list changed, or the network / Tor came back.
  void refresh() {
    _sync();
    for (final c in _conns.values) {
      if (c.socket == null) c.retryNow();
    }
  }

  void _sync() {
    if (_disposed) return;
    final wanted = _watched.isEmpty && _probes.isEmpty
        ? <String>{}
        : {..._ourRelays(), for (final r in _extra) ?normalizeRelayUrl(r)};
    for (final url in _conns.keys.toList()) {
      if (!wanted.contains(url)) _conns.remove(url)!.close();
    }
    for (final url in wanted) {
      final conn = _conns.putIfAbsent(url, () => _Conn(this, url)..open());
      conn.subscribe();
    }
  }

  /// Relays cap the filters of one REQ (NIP-11 `max_filters`, often 10).
  static const maxPostFilters = 7;

  /// A filter per channel, up to [maxPostFilters]: with a shared limit, one
  /// busy channel would push the others' history out of the reply. Beyond
  /// that, channels share filters.
  List<Object> get _filters => [
    for (final group in spreadChannels(_watched, maxPostFilters))
      {
        'kinds': [
          Channel.kindPost,
          Channel.kindMeta,
          Channel.kindEdit,
          Channel.kindPin,
        ],
        'authors': group,
        'limit': 500,
      },
    if (_probes.isNotEmpty)
      {
        'kinds': [Channel.kindMeta],
        'authors': (_probes.toList()..sort()),
      },
    {
      'kinds': [Channel.kindReaction],
      '#p': (_watched.toList()..sort()),
      'limit': 2000,
    },
  ];

  @override
  Future<void> publishChannelEvent(
    Nip01Event event, {
    List<String> relays = const [],
  }) async {
    final open = _conns.values.where((c) => c.socket != null).toList();
    if (open.isEmpty) throw StateError('offline');
    final message = jsonEncode([
      'EVENT',
      Nip01EventModel.fromEntity(event).toJson(),
    ]);
    final accepted = Completer<void>();
    var pending = open.length;
    for (final c in open) {
      c.send(message, okFor: event.id).then((ok) {
        if (ok && !accepted.isCompleted) accepted.complete();
        if (--pending == 0 && !accepted.isCompleted) {
          accepted.completeError(StateError('no relay accepted the event'));
        }
      });
    }
    await accepted.future.timeout(publishTimeout);
  }

  void dispose() {
    _disposed = true;
    for (final c in _conns.values) {
      c.close();
    }
    _conns.clear();
    _events.close();
  }
}

/// [pks] dealt into at most [groups] lists, in a stable order.
List<List<String>> spreadChannels(Set<String> pks, int groups) {
  final sorted = pks.toList()..sort();
  final n = sorted.length < groups ? sorted.length : groups;
  return [
    for (var g = 0; g < n; g++)
      [for (var i = g; i < sorted.length; i += n) sorted[i]],
  ];
}

class _Conn {
  _Conn(this.pool, this.url);

  final ChannelRelayPool pool;
  final String url;
  WebSocket? socket;
  bool _closed = false;
  bool _connecting = false;
  int _attempt = 0;
  Timer? _retry;
  String? _subscribedFilters;
  final Map<String, Completer<bool>> _oks = {};

  Future<void> open() async {
    if (_closed || _connecting || socket != null) return;
    _connecting = true;
    try {
      final ws = await WebSocket.connect(
        url,
        customClient: pool._httpClient(),
      ).timeout(const Duration(seconds: 30));
      _connecting = false;
      if (_closed) {
        await ws.close();
        return;
      }
      socket = ws;
      _attempt = 0;
      _subscribedFilters = null;
      ws.listen(_onMessage, onDone: _onDown, onError: (_) => _onDown());
      subscribe();
    } catch (_) {
      _connecting = false;
      _schedule();
    }
  }

  void retryNow() {
    _retry?.cancel();
    _attempt = 0;
    unawaited(open());
  }

  void _onDown() {
    socket = null;
    _subscribedFilters = null;
    for (final ok in _oks.values) {
      if (!ok.isCompleted) ok.complete(false);
    }
    _oks.clear();
    _schedule();
  }

  void _schedule() {
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(retryDelay(_attempt++, random: pool._random), open);
  }

  /// (Re)sends the REQ when the watched set changed.
  void subscribe() {
    final ws = socket;
    if (ws == null) return;
    final filters = jsonEncode(pool._filters);
    if (filters == _subscribedFilters) return;
    if (_subscribedFilters != null) {
      ws.add(jsonEncode(['CLOSE', ChannelRelayPool._subId]));
    }
    _subscribedFilters = filters;
    ws.add(jsonEncode(['REQ', ChannelRelayPool._subId, ...pool._filters]));
  }

  Future<bool> send(String message, {required String okFor}) {
    final ws = socket;
    if (ws == null) return Future.value(false);
    final ok = _oks[okFor] = Completer<bool>();
    ws.add(message);
    return ok.future.timeout(pool.publishTimeout, onTimeout: () => false);
  }

  void _onMessage(Object? data) {
    if (data is! String) return;
    final Object? msg;
    try {
      msg = jsonDecode(data);
    } catch (_) {
      return;
    }
    if (msg is! List || msg.isEmpty) return;
    switch (msg[0]) {
      case 'EVENT' when msg.length >= 3 && msg[2] is Map:
        try {
          pool._events.add(Nip01EventModel.fromJson(msg[2] as Map));
        } catch (_) {}
      case 'OK' when msg.length >= 3 && msg[1] is String:
        final ok = _oks.remove(msg[1]);
        if (ok != null && !ok.isCompleted) ok.complete(msg[2] == true);
    }
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    final ws = socket;
    socket = null;
    unawaited(ws?.close());
    for (final ok in _oks.values) {
      if (!ok.isCompleted) ok.complete(false);
    }
  }
}
