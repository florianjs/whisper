import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tor/arti.dart';

import '../logic/censorship.dart';
import '../logic/relays.dart';
import '../logic/tor_proxy.dart';
import 'key_vault.dart';

enum TorState { off, starting, ready, failed }

/// The embedded Tor client, abstracted for tests.
abstract class TorBackend {
  /// Starts Tor at [level] and waits for a circuit (bounded by
  /// [TorLevel.timeout]); returns the SOCKS5 port. Throws if it didn't
  /// bootstrap.
  Future<int> start(TorLevel level);
  Future<void> stop();
}

/// Arti (Tor in Rust) through the `tor` plugin, owned by a long-lived
/// background isolate: the plugin's bootstrap is a *blocking* native call
/// (~10 s), which on the UI isolate froze the whole app at every launch.
class ArtiBackend implements TorBackend {
  ArtiBackend();

  SendPort? _commands;
  Future<SendPort>? _spawning;

  Future<SendPort> _isolate() => _spawning ??= () async {
    final ready = ReceivePort();
    await Isolate.spawn(_torIsolateMain, (
      ready.sendPort,
      RootIsolateToken.instance!,
    ), debugName: 'tor');
    return _commands = await ready.first as SendPort;
  }();

  Future<Object?> _call(Object command) async {
    final isolate = await _isolate();
    final reply = ReceivePort();
    isolate.send((command, reply.sendPort));
    final result = await reply.first;
    if (result is String && result.startsWith('error:')) {
      throw StateError(result.substring(6));
    }
    return result;
  }

  /// Pluggable transports (IPtProxy) run in the Android app process.
  static const _pt = MethodChannel('whisper/pt');

  @override
  Future<int> start(TorLevel level) async {
    var ptProxy = '';
    final transport = level.transport;
    if (transport != null) {
      final port = await _pt
          .invokeMethod<int>('start', {
            'transport': transport,
            'params': transport == 'snowflake'
                ? snowflakeParams(level.bridges.first)
                : const <String, String>{},
          })
          .timeout(const Duration(seconds: 30));
      ptProxy = '127.0.0.1:$port';
    }
    return await _call((
          'start',
          level.name,
          level.bridges,
          transport ?? '',
          ptProxy,
          level.timeout.inSeconds,
        ))
        as int;
  }

  @override
  Future<void> stop() async {
    if (_commands != null) {
      await _call(('stop', '', const <String>[], '', '', 0));
    }
    // Pluggable transports stay up: the parked Arti client of their rung is
    // bound to their port. Idle, they only hold a loopback listener.
  }
}

/// Entry point of the Tor isolate: start/stop commands, replies on the
/// provided port. Platform channels (path_provider, used by the plugin) need
/// the background isolate messenger.
/// Debug-only trace of Tor lifecycle (no addresses, no keys).
void _trace(String message) {
  if (kDebugMode) debugPrint('WHISPER_TOR $message');
}

Future<void> _torIsolateMain((SendPort, RootIsolateToken) args) async {
  final (ready, token) = args;
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final commands = ReceivePort();
  ready.send(commands.sendPort);
  await for (final message in commands) {
    final (command, reply) =
        message
            as ((String, String, List<String>, String, String, int), SendPort);
    final (name, level, bridges, ptProtocol, ptProxy, timeoutSecs) = command;
    try {
      switch (name) {
        case 'start':
          final t0 = DateTime.now();
          _trace(
            'isolate: starting arti (${ptProtocol.isEmpty ? 'tor' : ptProtocol})',
          );
          final support = await getApplicationSupportDirectory();
          // One state/cache dir per rung: each rung has its own long-lived
          // Arti client (see rust/src/lib.rs CLIENTS), and a client locks its
          // state dir.
          final state = await Directory(
            '${support.path}/tor_state/$level',
          ).create(recursive: true);
          final cache = await Directory(
            '${support.path}/tor_cache/$level',
          ).create(recursive: true);
          // Free loopback port for Arti's SOCKS listener.
          final probe = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final port = probe.port;
          await probe.close();
          Arti.start(
            socksPort: port,
            stateDir: state.path,
            cacheDir: cache.path,
            config: ArtiConfig(
              bridges: bridges,
              ptProtocol: ptProtocol,
              ptProxy: ptProxy,
              timeout: Duration(seconds: timeoutSecs),
            ),
          );
          _trace(
            'isolate: bootstrapped in '
            '${DateTime.now().difference(t0).inMilliseconds} ms',
          );
          reply.send(port);
        case 'stop':
          Arti.stop();
          reply.send(null);
      }
    } catch (e) {
      _trace('isolate: $name failed: $e');
      reply.send('error:$e');
    }
  }
}

/// Runs Tor + the local CONNECT proxy. On by default (decision 2026-09-30):
/// direct connections reveal the user's IP and that they use Nostr, and
/// uniform Tor use means enabling it is not a signal. Preferences live in the
/// plain Keystore vault so they're known before the app is unlocked.
///
/// When Tor doesn't bootstrap in time the service climbs [torLadder] on its
/// own (obfs4, then Snowflake) and remembers what worked.
class TorService extends ChangeNotifier {
  TorService(this._vault, {TorBackend? backend, Random? random})
    : _backend = backend ?? ArtiBackend(),
      _random = random ?? Random();

  static const _prefKey = 'tor_mode';
  static const _disguiseKey = 'tor_disguise';
  static const _levelKey = 'tor_level';

  /// Everything this service keeps in the vault (for the panic wipe).
  static const vaultKeys = [_prefKey, _disguiseKey, _levelKey];

  /// Arti state/cache (guards, consensus) and pluggable-transport files, for
  /// the panic wipe. Running clients keep going from memory; nothing about
  /// which bridges or guards this phone used survives on disk.
  static Future<void> clearDiskState() async {
    final support = await getApplicationSupportDirectory();
    final temp = await getTemporaryDirectory();
    for (final dir in [
      Directory('${support.path}/tor_state'),
      Directory('${support.path}/tor_cache'),
      Directory('${temp.path}/pt'),
    ]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  final KeyVault _vault;
  final TorBackend _backend;
  final Random _random;

  bool _wanted = true;
  bool get wanted => _wanted;

  /// Never use plain Tor: only disguised rungs.
  bool _disguise = false;
  bool get disguise => _disguise;

  TorLevel? _lastGood;

  /// Rung being tried (starting) or in use (ready).
  TorLevel? _level;
  TorLevel? get level => _level;

  TorState _state = TorState.off;
  TorState get state => _state;

  ConnectProxy? _proxy;
  ConnectProxy? get proxy => _proxy;

  Timer? _retry;
  int _attempt = 0;

  /// Bumped by every stop: a ladder run from before must not finish.
  int _generation = 0;

  Future<void> init() async {
    _wanted = await _vault.read(_prefKey) != 'off';
    _disguise = await _vault.read(_disguiseKey) == 'on';
    final saved = await _vault.read(_levelKey);
    _lastGood = TorLevel.values.where((l) => l.name == saved).firstOrNull;
    if (_wanted) unawaited(_start());
  }

  Future<void> setWanted(bool wanted) async {
    if (wanted == _wanted) return;
    _wanted = wanted;
    await _vault.write(_prefKey, wanted ? 'on' : 'off');
    notifyListeners();
    wanted ? await _start() : await _stop();
  }

  Future<void> setDisguise(bool disguise) async {
    if (disguise == _disguise) return;
    _disguise = disguise;
    await _vault.write(_disguiseKey, disguise ? 'on' : 'off');
    notifyListeners();
    // Plain Tor in use (or being tried) while disguise is now required:
    // switch right away. Turning it off keeps the current disguised link.
    if (_wanted && disguise && _level == TorLevel.tor) {
      await _stop(keepWanted: true);
      await _start();
    }
  }

  Future<void> _start() async {
    if (_state == TorState.starting || _state == TorState.ready) return;
    _retry?.cancel();
    final generation = ++_generation;
    _state = TorState.starting;
    notifyListeners();
    for (final level in torLadder(lastGood: _lastGood, disguise: _disguise)) {
      if (generation != _generation || !_wanted) return;
      _level = level;
      notifyListeners();
      try {
        _trace('trying ${level.name}');
        final socksPort = await _backend.start(level);
        final proxy = ConnectProxy(socksPort: socksPort);
        await proxy.start();
        if (generation != _generation || !_wanted) {
          // Stopped or switched off while bootstrapping.
          await proxy.stop();
          return;
        }
        _proxy = proxy;
        _attempt = 0;
        _state = TorState.ready;
        if (_lastGood != level) {
          _lastGood = level;
          await _vault.write(_levelKey, level.name);
        }
        _trace('ready (${level.name}), local proxy up');
        notifyListeners();
        return;
      } catch (e) {
        _trace('${level.name} failed: $e');
        try {
          await _backend.stop();
        } catch (_) {}
      }
    }
    if (generation != _generation) return;
    // Every rung failed (offline, or everything blocked): stay fail-closed
    // and go around again later.
    _state = TorState.failed;
    _retry = Timer(retryDelay(_attempt++, random: _random), _start);
    notifyListeners();
  }

  Future<void> _stop({bool keepWanted = false}) async {
    _generation++;
    _retry?.cancel();
    final proxy = _proxy;
    _proxy = null;
    await proxy?.stop();
    try {
      await _backend.stop();
    } catch (_) {}
    _state = TorState.off;
    if (!keepWanted) _level = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _retry?.cancel();
    unawaited(_proxy?.stop());
    super.dispose();
  }
}
