import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'identity_store.dart';
import 'notifier.dart';
import 'relay_service.dart';
import 'settings_store.dart';

/// The platform side of background delivery: a foreground service that keeps
/// the process alive, and content-free notifications.
class PlatformBackground implements NotificationSink {
  PlatformBackground(this._strings);

  static const _channel = MethodChannel('whisper/background');
  final AppLocalizations Function() _strings;

  Future<void> start() {
    final l = _strings();
    return _invoke('start', {
      'title': l.bgConnectionTitle,
      'text': l.bgConnectionText,
    });
  }

  Future<void> stop() => _invoke('stop');

  @override
  Future<void> show(int count) => _invoke('notify', {
    'title': 'Whisper',
    'text': _strings().notifyNew(count),
  });

  @override
  Future<void> clear() => _invoke('clear');

  Future<void> _invoke(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not on Android (tests, other platforms): nothing to do.
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('background $method failed: ${e.message}');
    }
  }
}

/// Runs the foreground service exactly while there is an account to receive
/// for (unlocked, or locked with its inbox watched) and the user wants it;
/// wipes notifications on sign-out.
class BackgroundDelivery {
  BackgroundDelivery({
    required IdentityStore identity,
    required SettingsStore settings,
    required PlatformBackground platform,
    required this.notifier,
    RelayService? relays,
  }) : _identity = identity,
       _settings = settings,
       _platform = platform,
       _relays = relays {
    _identity.addListener(_sync);
    _settings.addListener(_sync);
    _relays?.addListener(_sync);
    _sealed = _relays?.sealedArrivals.listen((_) => notifier.sealedArrival());
    _sync();
  }

  final IdentityStore _identity;
  final SettingsStore _settings;
  final PlatformBackground _platform;
  final RelayService? _relays;
  final ArrivalNotifier notifier;
  StreamSubscription<String>? _sealed;
  bool? _running;

  void _sync() {
    final watching = _relays?.watching ?? false;
    final want = (_identity.hasIdentity || watching) && _settings.background;
    if (!_identity.hasIdentity && !watching) unawaited(notifier.reset());
    if (want == _running) return;
    _running = want;
    unawaited(want ? _platform.start() : _platform.stop());
  }

  void setForeground(bool foreground) => notifier.setForeground(foreground);

  void dispose() {
    _identity.removeListener(_sync);
    _settings.removeListener(_sync);
    _relays?.removeListener(_sync);
    unawaited(_sealed?.cancel());
    notifier.dispose();
  }
}
