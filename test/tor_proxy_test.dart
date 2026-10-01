import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/tor_proxy.dart';

/// Fake Tor: accepts SOCKS5 CONNECT, records the requested target, then
/// echoes everything back upper-cased.
class FakeSocks {
  late ServerSocket server;
  final requested = <String>[];
  final isolation = <String>[];

  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) {
      final buf = <int>[];
      var stage = 0;
      s.listen((d) {
        if (stage == 2) {
          s.add(
            utf8.encode(utf8.decode(d, allowMalformed: true).toUpperCase()),
          );
          return;
        }
        buf.addAll(d);
        if (stage == 0 && buf.length >= 3) {
          expect(buf.sublist(0, 3), [5, 1, 2], reason: 'user/pass auth');
          buf.removeRange(0, 3);
          s.add([5, 2]);
          stage = 3;
        }
        if (stage == 3 && buf.length >= 2) {
          final ulen = buf[1];
          if (buf.length < 2 + ulen + 1) return;
          final plen = buf[2 + ulen];
          if (buf.length < 3 + ulen + plen) return;
          isolation.add(utf8.decode(buf.sublist(2, 2 + ulen)));
          buf.removeRange(0, 3 + ulen + plen);
          s.add([1, 0]);
          stage = 1;
        }
        if (stage == 1 && buf.length >= 5) {
          final atyp = buf[3];
          final len = buf[4];
          if (buf.length < 5 + len + 2) return;
          expect(atyp, 3, reason: 'must send the hostname, not an IP');
          final host = utf8.decode(buf.sublist(5, 5 + len));
          final port = buf[5 + len] << 8 | buf[6 + len];
          requested.add('$host:$port');
          buf.clear();
          s.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
          stage = 2;
        }
      });
    });
  }
}

Future<(Socket, Stream<String>)> rawConnect(int port, String request) async {
  final s = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final out = s.map(utf8.decode).asBroadcastStream();
  s.add(utf8.encode(request));
  return (s, out);
}

void main() {
  late FakeSocks socks;
  late ConnectProxy proxy;

  setUp(() async {
    socks = FakeSocks();
    await socks.start();
    proxy = ConnectProxy(socksPort: socks.server.port);
    await proxy.start();
  });

  tearDown(() async {
    await proxy.stop();
    await socks.server.close();
  });

  String auth() =>
      base64Encode(utf8.encode('${ConnectProxy.username}:${proxy.password}'));

  test('CONNECT tunnels through SOCKS by hostname, both directions', () async {
    final (s, out) = await rawConnect(
      proxy.port,
      'CONNECT nos.lol:443 HTTP/1.1\r\nHost: nos.lol:443\r\n'
      'Proxy-Authorization: Basic ${auth()}\r\n\r\n',
    );
    expect(await out.first, startsWith('HTTP/1.1 200'));
    s.add(utf8.encode('hello tor'));
    expect(await out.first, 'HELLO TOR');
    expect(socks.requested, ['nos.lol:443']);
    s.destroy();
  });

  test('bytes sent right after the header are not lost', () async {
    final (s, out) = await rawConnect(
      proxy.port,
      'CONNECT relay.example:443 HTTP/1.1\r\n'
      'Proxy-Authorization: Basic ${auth()}\r\n\r\nearly',
    );
    final chunks = await out.take(2).join();
    expect(chunks, contains('200'));
    expect(chunks, contains('EARLY'));
    s.destroy();
  });

  test('no or wrong password → 407, nothing reaches Tor', () async {
    final (a, outA) = await rawConnect(
      proxy.port,
      'CONNECT nos.lol:443 HTTP/1.1\r\n\r\n',
    );
    expect(await outA.first, startsWith('HTTP/1.1 407'));
    final bad = base64Encode(utf8.encode('whisper:guess'));
    final (b, outB) = await rawConnect(
      proxy.port,
      'CONNECT nos.lol:443 HTTP/1.1\r\nProxy-Authorization: Basic $bad\r\n\r\n',
    );
    expect(await outB.first, startsWith('HTTP/1.1 407'));
    expect(socks.requested, isEmpty);
    a.destroy();
    b.destroy();
  });

  test('plain requests to clearnet hosts are refused', () async {
    final (s, out) = await rawConnect(
      proxy.port,
      'GET http://example.com/ HTTP/1.1\r\n'
      'Proxy-Authorization: Basic ${auth()}\r\n\r\n',
    );
    expect(await out.first, startsWith('HTTP/1.1 405'));
    expect(socks.requested, isEmpty);
    s.destroy();
  });

  test('plain ws:// to an onion relay is forwarded in origin form', () async {
    const onion =
        'abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwx.onion';
    final (s, out) = await rawConnect(
      proxy.port,
      'GET http://$onion/ HTTP/1.1\r\n'
      'Host: $onion\r\n'
      'Upgrade: websocket\r\n'
      'Proxy-Authorization: Basic ${auth()}\r\n\r\n',
    );
    final echoed = await out.first;
    expect(socks.requested, ['$onion:80']);
    // The fake Tor echoes upper-cased: what the onion service received.
    expect(echoed, startsWith('GET / HTTP/1.1\r\n'));
    expect(echoed, contains('UPGRADE: WEBSOCKET'));
    expect(echoed, isNot(contains('PROXY-AUTHORIZATION')));
    s.destroy();
  });

  test('dart:io\'s port 0 for proxied ws:// means 80', () async {
    const onion = 'abcdef.onion';
    final (s, out) = await rawConnect(
      proxy.port,
      'GET http://$onion:0 HTTP/1.1\r\n'
      'Host: $onion:0\r\n'
      'Proxy-Authorization: Basic ${auth()}\r\n\r\n',
    );
    final echoed = await out.first;
    expect(socks.requested, ['$onion:80']);
    expect(echoed, contains('HOST: ABCDEF.ONION\r\n'));
    expect(echoed, isNot(contains(':0')));
    s.destroy();
  });

  test('plain request without password is refused', () async {
    final (s, out) = await rawConnect(
      proxy.port,
      'GET http://abc.onion/ HTTP/1.1\r\n\r\n',
    );
    expect(await out.first, startsWith('HTTP/1.1 407'));
    expect(socks.requested, isEmpty);
    s.destroy();
  });

  test('listens on loopback only', () async {
    expect(proxy.running, isTrue);
    final nonLoopback = (await NetworkInterface.list())
        .expand((i) => i.addresses)
        .where((a) => !a.isLoopback && a.type == InternetAddressType.IPv4);
    for (final addr in nonLoopback) {
      await expectLater(
        Socket.connect(addr, proxy.port, timeout: const Duration(seconds: 1)),
        throwsA(isA<SocketException>()),
      );
    }
  });

  group('decideProxy (fail-closed)', () {
    test('Tor off → direct', () {
      expect(decideProxy(torWanted: false, proxy: proxy), 'DIRECT');
    });

    test('Tor wanted but not ready → dead proxy, never direct', () async {
      expect(decideProxy(torWanted: true, proxy: null), 'PROXY 127.0.0.1:1');
      await proxy.stop();
      expect(decideProxy(torWanted: true, proxy: proxy), 'PROXY 127.0.0.1:1');
    });

    test('Tor ready → our proxy with credentials', () {
      expect(
        decideProxy(torWanted: true, proxy: proxy),
        'PROXY whisper:${proxy.password}@127.0.0.1:${proxy.port}',
      );
    });
  });

  test(
    'HttpClient with the overrides really uses the tunnel (https)',
    () async {
      final overrides = TorHttpOverrides(() => (wanted: true, proxy: proxy));
      final client = overrides.createHttpClient(null)
        ..connectionTimeout = const Duration(seconds: 3);
      // The fake "Tor" answers garbage instead of TLS, so the request fails —
      // but only after going through our CONNECT → SOCKS path.
      await expectLater(
        client
            .getUrl(Uri.parse('https://relay.example/'))
            .then((r) => r.close()),
        throwsA(anything),
      );
      expect(socks.requested, ['relay.example:443']);
      client.close(force: true);
    },
  );

  test('Tor wanted but down: HttpClient cannot connect at all', () async {
    final overrides = TorHttpOverrides(() => (wanted: true, proxy: null));
    final client = overrides.createHttpClient(null)
      ..connectionTimeout = const Duration(seconds: 3);
    await expectLater(
      client.getUrl(Uri.parse('https://example.com/')),
      throwsA(isA<SocketException>()),
    );
    client.close(force: true);
  });

  test(
    'each proxy user gets its own Tor isolation, strangers get 407',
    () async {
      String basic(String user) =>
          base64Encode(utf8.encode('$user:${proxy.password}'));
      for (final user in [ConnectProxy.username, ConnectProxy.channelsUser]) {
        final (s, out) = await rawConnect(
          proxy.port,
          'CONNECT nos.lol:443 HTTP/1.1\r\n'
          'Proxy-Authorization: Basic ${basic(user)}\r\n\r\n',
        );
        expect(await out.first, startsWith('HTTP/1.1 200'));
        s.destroy();
      }
      expect(socks.isolation, [
        ConnectProxy.username,
        ConnectProxy.channelsUser,
      ]);

      final (s, out) = await rawConnect(
        proxy.port,
        'CONNECT nos.lol:443 HTTP/1.1\r\n'
        'Proxy-Authorization: Basic ${basic('someone')}\r\n\r\n',
      );
      expect(await out.first, startsWith('HTTP/1.1 407'));
      s.destroy();
    },
  );

  test('isolated clients stay fail-closed', () {
    expect(
      decideProxy(
        torWanted: true,
        proxy: null,
        user: ConnectProxy.channelsUser,
      ),
      'PROXY 127.0.0.1:1',
    );
    expect(
      decideProxy(
        torWanted: true,
        proxy: proxy,
        user: ConnectProxy.channelsUser,
      ),
      startsWith('PROXY ${ConnectProxy.channelsUser}:'),
    );
  });
}
