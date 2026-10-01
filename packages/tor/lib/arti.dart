// Whisper additions to the vendored `tor` plugin: a bounded start with
// bridges / pluggable transports (see rust/src/lib.rs `tor_start_with`).

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tor/generated_bindings.dart' show Tor;
import 'package:tor/tor.dart' as plugin show Tor, load;

/// How Tor should reach the network.
class ArtiConfig {
  const ArtiConfig({
    this.bridges = const [],
    this.ptProtocol = '',
    this.ptProxy = '',
    this.timeout = const Duration(seconds: 60),
  });

  /// Bridge lines ("obfs4 1.2.3.4:443 FP cert=… iat-mode=0"); empty = direct.
  final List<String> bridges;

  /// Unmanaged pluggable transport already listening locally, e.g.
  /// "snowflake" at "127.0.0.1:41234". Empty when none is needed.
  final String ptProtocol;
  final String ptProxy;
  final Duration timeout;
}

class ArtiException implements Exception {
  ArtiException(this.message);
  final String message;
  @override
  String toString() => 'ArtiException: $message';
}

typedef _StartNative = Tor Function(
  Uint16,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Uint32,
);
typedef _Start = Tor Function(
  int,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  int,
);

/// One Tor client at a time, owned by the calling isolate. [start] blocks
/// that isolate until bootstrapped or [ArtiConfig.timeout]: call it from a
/// background isolate.
class Arti {
  Arti._();

  static final DynamicLibrary _lib = plugin.load(plugin.Tor.libName);
  static final _start = _lib.lookupFunction<_StartNative, _Start>(
    'tor_start_with',
  );
  static final _proxyStop = _lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>(
    'tor_proxy_stop',
  );
  static final _clientFree = _lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>(
    'tor_client_free',
  );
  static final _lastError =
      _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
    'tor_last_error_message',
  );

  static Pointer<Void> _client = nullptr;
  static Pointer<Void> _proxy = nullptr;

  static bool get running => _client != nullptr;

  /// Starts Tor with [config] and a SOCKS5 proxy on [socksPort].
  static void start({
    required int socksPort,
    required String stateDir,
    required String cacheDir,
    ArtiConfig config = const ArtiConfig(),
  }) {
    stop();
    final args = [
      stateDir,
      cacheDir,
      config.bridges.join('\n'),
      config.ptProtocol,
      config.ptProxy,
    ].map((s) => s.toNativeUtf8()).toList();
    try {
      final tor = _start(
        socksPort,
        args[0],
        args[1],
        args[2],
        args[3],
        args[4],
        config.timeout.inSeconds,
      );
      if (tor.client == nullptr) {
        final err = _lastError();
        throw ArtiException(
            err == nullptr ? 'start failed' : err.toDartString());
      }
      _client = tor.client;
      _proxy = tor.proxy;
    } finally {
      args.forEach(malloc.free);
    }
  }

  static void stop() {
    if (_proxy != nullptr) _proxyStop(_proxy);
    if (_client != nullptr) _clientFree(_client);
    _proxy = nullptr;
    _client = nullptr;
  }
}
