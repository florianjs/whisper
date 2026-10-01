import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/tor_service.dart';
import 'package:whisper/logic/censorship.dart';
import 'package:whisper/logic/tor_proxy.dart';

class FakeTor implements TorBackend {
  int starts = 0;
  int stops = 0;
  int failuresLeft = 0;
  Completer<void>? gate;

  /// Rungs that never bootstrap (simulated censorship).
  Set<TorLevel> blocked = {};
  final tried = <TorLevel>[];

  @override
  Future<int> start(TorLevel level) async {
    starts++;
    tried.add(level);
    await gate?.future;
    if (blocked.contains(level)) throw StateError('timed out');
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const SocketException('no network');
    }
    return 9050;
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  late MemoryKeyVault vault;
  late FakeTor tor;
  setUp(() {
    vault = MemoryKeyVault();
    tor = FakeTor();
  });

  Future<TorService> started() async {
    final s = TorService(vault, backend: tor);
    await s.init();
    for (var i = 0; i < 20 && s.state != TorState.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return s;
  }

  test('on by default: starts Tor and the local proxy', () async {
    final s = await started();
    expect(s.wanted, isTrue);
    expect(s.state, TorState.ready);
    expect(s.proxy!.running, isTrue);
    expect(s.proxy!.socksPort, 9050);
    expect(
      decideProxy(torWanted: s.wanted, proxy: s.proxy),
      startsWith('PROXY whisper:'),
    );
    await s.setWanted(false);
  });

  test('while bootstrapping, traffic is blocked (fail-closed)', () async {
    tor.gate = Completer();
    final s = TorService(vault, backend: tor);
    await s.init();
    expect(s.state, TorState.starting);
    expect(
      decideProxy(torWanted: s.wanted, proxy: s.proxy),
      'PROXY 127.0.0.1:1',
    );
    tor.gate!.complete();
    await s.setWanted(false);
  });

  test('turning it off stops Tor, persists, goes direct', () async {
    final s = await started();
    await s.setWanted(false);
    expect(s.state, TorState.off);
    expect(tor.stops, 1);
    expect(decideProxy(torWanted: s.wanted, proxy: s.proxy), 'DIRECT');

    final again = TorService(vault, backend: tor);
    await again.init();
    expect(again.wanted, isFalse);
    expect(tor.starts, 1, reason: 'not restarted when off');
  });

  test('failure stays fail-closed and retries', () async {
    tor.failuresLeft = 3; // every rung of the ladder
    final s = TorService(vault, backend: tor);
    await s.init();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(s.state, TorState.failed);
    expect(
      decideProxy(torWanted: s.wanted, proxy: s.proxy),
      'PROXY 127.0.0.1:1',
    );
    // First retry is ~2 s later.
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    expect(s.state, TorState.ready);
    expect(tor.starts, 4);
    await s.setWanted(false);
  });

  test('Tor blocked: climbs to a disguised rung and remembers it', () async {
    tor.blocked = {TorLevel.tor, TorLevel.obfs4};
    final s = await started();
    expect(s.state, TorState.ready);
    expect(s.level, TorLevel.snowflake);
    expect(tor.tried, [TorLevel.tor, TorLevel.obfs4, TorLevel.snowflake]);
    expect(tor.stops, 2, reason: 'each failed rung is torn down');
    await s.setWanted(false);

    // Next launch starts where it worked: no plain-Tor attempt first.
    tor.tried.clear();
    await s.setWanted(true);
    for (var i = 0; i < 20 && s.state != TorState.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(tor.tried.first, TorLevel.snowflake);
    final again = TorService(vault, backend: tor);
    tor.tried.clear();
    await again.init();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(tor.tried.first, TorLevel.snowflake);
    await again.setWanted(false);
    await s.setWanted(false);
  });

  test('traffic stays blocked while climbing', () async {
    tor.blocked = {TorLevel.tor};
    tor.gate = Completer();
    final s = TorService(vault, backend: tor);
    await s.init();
    expect(decideProxy(torWanted: true, proxy: s.proxy), 'PROXY 127.0.0.1:1');
    tor.gate!.complete();
    for (var i = 0; i < 20 && s.state != TorState.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(s.level, TorLevel.obfs4);
    await s.setWanted(false);
  });

  test('disguise: plain Tor is never tried, and is left at once', () async {
    final s = await started();
    expect(s.level, TorLevel.tor);
    tor.tried.clear();
    await s.setDisguise(true);
    for (var i = 0; i < 20 && s.state != TorState.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(s.level, TorLevel.obfs4);
    expect(tor.tried, isNot(contains(TorLevel.tor)));

    final again = TorService(vault, backend: tor);
    tor.tried.clear();
    await again.init();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again.disguise, isTrue);
    expect(tor.tried, isNot(contains(TorLevel.tor)));
    await again.setWanted(false);
    await s.setWanted(false);
  });
}
