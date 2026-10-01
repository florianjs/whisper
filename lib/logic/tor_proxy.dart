import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Where HTTP/WebSocket traffic must go. Fail-closed: when Tor is wanted but
/// not ready, connections are pointed at a dead port instead of going direct
/// — a direct connection would reveal the user's IP (the thing Tor hides).
String decideProxy({
  required bool torWanted,
  required ConnectProxy? proxy,
  String user = ConnectProxy.username,
}) {
  if (!torWanted) return 'DIRECT';
  if (proxy == null || !proxy.running) return 'PROXY 127.0.0.1:1';
  // Credentials inline: dart:io sends them preemptively (Basic).
  return 'PROXY $user:${proxy.password}@127.0.0.1:${proxy.port}';
}

/// Local HTTP CONNECT proxy in front of Tor's SOCKS5 port.
///
/// dart:io's HttpClient (hence WebSocket.connect, used by ndk) speaks HTTP
/// proxies but not SOCKS; this bridges the two. The target *hostname* is
/// passed to Tor, which resolves it at the exit: no local DNS lookup leaks.
/// Loopback only, and gated by a random password so other apps on the phone
/// can't borrow the tunnel.
class ConnectProxy {
  ConnectProxy({required this.socksPort, Random? random})
    : password = _token(random ?? Random.secure());

  final int socksPort;
  static const username = 'whisper';

  /// Second identity for traffic that must not share Tor circuits with the
  /// main one (channel subscriptions vs. the inbox): Arti isolates streams
  /// by SOCKS credentials, so each user gets its own circuits and exits.
  static const channelsUser = 'whisper-ch';
  static const _users = {username, channelsUser};
  final String password;
  ServerSocket? _server;

  int get port => _server!.port;
  bool get running => _server != null;

  static String _token(Random r) => List.generate(
    24,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<void> start() async {
    _server ??= await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((client) => unawaited(_handle(client)));
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  Future<void> _handle(Socket client) async {
    final buffer = <int>[];
    StreamSubscription<List<int>>? clientSub;
    Socket? upstream;
    Stream<List<int>>? upstreamData;
    var headerDone = false;

    void fail(int code, String reason) {
      client.add(utf8.encode('HTTP/1.1 $code $reason\r\n\r\n'));
      client.destroy();
      upstream?.destroy();
    }

    clientSub = client.listen(
      (data) async {
        if (headerDone) {
          upstream?.add(data);
          return;
        }
        buffer.addAll(data);
        final end = _indexOf(buffer, const [13, 10, 13, 10]);
        if (end < 0) {
          if (buffer.length > 8192) fail(431, 'Header Too Large');
          return;
        }
        headerDone = true;
        clientSub!.pause();
        final header = latin1.decode(buffer.sublist(0, end));
        final rest = buffer.sublist(end + 4);
        final lines = header.split('\r\n');
        final parts = lines.first.split(' ');
        if (parts.length < 3) return fail(400, 'Bad Request');
        final user = _authorized(lines.skip(1));
        if (user == null) {
          return fail(407, 'Proxy Authentication Required');
        }
        final connect = parts[0] == 'CONNECT';
        // Plain requests (ws:// to an onion relay) arrive in absolute form.
        // Only onion targets: their circuit is end-to-end encrypted and
        // authenticated by the address; plain text to a clearnet host would
        // be readable at the Tor exit.
        final plain = connect ? null : _parsePlain(parts[1]);
        if (!connect && plain == null) {
          return fail(405, 'Method Not Allowed');
        }
        final target = connect ? _parseTarget(parts[1]) : plain!.target;
        if (target == null) return fail(400, 'Bad Request');
        try {
          final (socket, data) = await _socksConnect(
            target.$1,
            target.$2,
            isolation: user,
          );
          upstream = socket;
          upstreamData = data;
        } catch (_) {
          return fail(502, 'Bad Gateway');
        }
        if (connect) {
          client.add(
            utf8.encode('HTTP/1.1 200 Connection Established\r\n\r\n'),
          );
        } else {
          // Origin-form request line; proxy credentials stay here.
          final (host, port) = plain!.target;
          final forwarded = [
            '${parts[0]} ${plain.path} ${parts[2]}',
            'Host: ${port == 80 ? host : '$host:$port'}',
            ...lines.skip(1).where((h) {
              final lower = h.toLowerCase();
              return !lower.startsWith('proxy-') && !lower.startsWith('host:');
            }),
          ].join('\r\n');
          upstream!.add(latin1.encode('$forwarded\r\n\r\n'));
        }
        if (rest.isNotEmpty) upstream!.add(rest);
        upstreamData!.listen(
          client.add,
          onDone: client.destroy,
          onError: (_) => client.destroy(),
          cancelOnError: true,
        );
        clientSub.resume();
      },
      onDone: () => upstream?.destroy(),
      onError: (_) => upstream?.destroy(),
      cancelOnError: true,
    );
  }

  /// The proxy user whose credentials are in [headers], or null.
  String? _authorized(Iterable<String> headers) {
    for (final user in _users) {
      final expected = base64Encode(utf8.encode('$user:$password'));
      final ok = headers.any(
        (h) =>
            h.toLowerCase().startsWith('proxy-authorization:') &&
            h.substring(h.indexOf(':') + 1).trim() == 'Basic $expected',
      );
      if (ok) return user;
    }
    return null;
  }

  /// `http://<name>.onion[:port]/path` → target + origin-form path.
  static ({(String, int) target, String path})? _parsePlain(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'http') return null;
    final host = uri.host.toLowerCase();
    if (!host.endsWith('.onion') || host.length > 255) return null;
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    // dart:io writes `ws://x.onion` as `http://x.onion:0` when proxying.
    final port = uri.hasPort && uri.port != 0 ? uri.port : 80;
    return (target: (host, port), path: path.isEmpty ? '/' : path);
  }

  static (String, int)? _parseTarget(String authority) {
    final i = authority.lastIndexOf(':');
    if (i <= 0) return null;
    final host = authority.substring(0, i);
    final port = int.tryParse(authority.substring(i + 1));
    if (port == null || port <= 0 || port > 65535 || host.length > 255) {
      return null;
    }
    return (host, port);
  }

  /// SOCKS5 CONNECT by *domain name* (ATYP 3), no auth. Returns the socket
  /// (to write to) and its incoming data, starting after the SOCKS reply.
  Future<(Socket, Stream<List<int>>)> _socksConnect(
    String host,
    int port, {
    required String isolation,
  }) async {
    final s = await Socket.connect(InternetAddress.loopbackIPv4, socksPort);
    final incoming = StreamController<List<int>>();
    final pending = <int>[];
    Completer<void>? wake;
    var handshake = true;
    s.listen(
      (d) {
        if (!handshake) return incoming.add(d);
        pending.addAll(d);
        wake?.complete();
        wake = null;
      },
      onDone: () {
        incoming.close();
        wake?.complete();
      },
      onError: incoming.addError,
    );
    Future<List<int>> take(int n) async {
      while (pending.length < n) {
        if (incoming.isClosed) throw StateError('socks closed');
        wake = Completer<void>();
        await wake!.future.timeout(const Duration(seconds: 60));
      }
      final out = pending.sublist(0, n);
      pending.removeRange(0, n);
      return out;
    }

    try {
      // Username/password auth, used by Arti as the stream isolation key:
      // (user, this proxy's random password). A new proxy (Tor restart)
      // gets fresh circuits too.
      s.add([5, 1, 2]);
      final hello = await take(2);
      if (hello[0] != 5 || hello[1] != 2) throw StateError('socks auth');
      final u = utf8.encode(isolation);
      final p = utf8.encode(password);
      s.add([1, u.length, ...u, p.length, ...p]);
      final auth = await take(2);
      if (auth[1] != 0) throw StateError('socks auth refused');
      final h = utf8.encode(host);
      s.add([5, 1, 0, 3, h.length, ...h, port >> 8, port & 0xff]);
      final head = await take(4);
      if (head[1] != 0) throw StateError('socks connect ${head[1]}');
      // Skip the bound address in the reply.
      final addrLen = switch (head[3]) {
        1 => 4,
        4 => 16,
        3 => (await take(1))[0],
        _ => throw StateError('socks atyp'),
      };
      await take(addrLen + 2);
    } catch (_) {
      s.destroy();
      rethrow;
    }
    handshake = false;
    if (pending.isNotEmpty) incoming.add(List.of(pending));
    return (s, incoming.stream);
  }

  static int _indexOf(List<int> data, List<int> needle) {
    outer:
    for (var i = 0; i <= data.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}

/// Routes every dart:io HttpClient (WebSocket.connect included) through
/// [decideProxy]. Installed once at startup, before anything connects.
class TorHttpOverrides extends HttpOverrides {
  TorHttpOverrides(this._state);

  final ({bool wanted, ConnectProxy? proxy}) Function() _state;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) {
      final state = _state();
      return decideProxy(torWanted: state.wanted, proxy: state.proxy);
    };
    return client;
  }

  /// A client whose traffic uses its own Tor circuits ([user] is one of
  /// ConnectProxy's users). Same fail-closed rule as every other client.
  HttpClient isolated(String user) {
    final client = super.createHttpClient(null);
    client.findProxy = (_) {
      final state = _state();
      return decideProxy(
        torWanted: state.wanted,
        proxy: state.proxy,
        user: user,
      );
    };
    return client;
  }
}
