import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hashlib/hashlib.dart' show sha256;

import '../l10n/app_localizations.dart';
import '../logic/update.dart';
import 'settings_store.dart';

/// What this phone is: null when in-app updates can't apply (not Android).
typedef UpdateDevice = ({String version, List<String> abis, String? installer});

/// The Android side (Updater.kt). Abstract for tests.
abstract class UpdatePlatform {
  Future<UpdateDevice?> device();
  Future<Directory> downloadDir();
  Future<bool> canInstall();
  Future<void> openInstallPermission();

  /// Checks (same app, newer, signed with [cert]) then installs. Throws a
  /// [PlatformException] whose code says why it refused.
  Future<void> install(String path, String cert);
  Future<void> notify(String title, String text);

  /// `pending` (Android asks the user), `success`, `failed`.
  Stream<String> get statuses;
}

/// The network side. Every connection goes through Tor
/// (TorHttpOverrides): GitHub sees a Tor exit, not the phone.
abstract class UpdateHttp {
  /// `Location` of [uri]'s redirect, without following it.
  Future<Uri?> redirectOf(Uri uri);
  Future<String> text(Uri uri);
  Future<void> download(
    Uri uri,
    File to, {
    required void Function(int received, int? total) onProgress,
  });
}

enum UpdateStage {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  failed,
}

enum UpdateFailure { network, checksum, signature, permission, install }

/// Finds, downloads, verifies and hands over new releases to the installer.
///
/// Checks about once a day at a random time, only while an account is open
/// and the setting is on; a manual check ignores both. Store installs (Play,
/// F-Droid, Obtainium) are left to their store.
class UpdateService extends ChangeNotifier {
  UpdateService({
    required SettingsStore settings,
    required UpdatePlatform platform,
    required AppLocalizations Function() strings,
    required bool Function() ready,
    UpdateHttp? http,
    Random? random,
  }) : _settings = settings,
       _platform = platform,
       _strings = strings,
       _ready = ready,
       _http = http ?? IoUpdateHttp(),
       _random = random ?? Random.secure();

  final SettingsStore _settings;
  final UpdatePlatform _platform;
  final AppLocalizations Function() _strings;
  final bool Function() _ready;
  final UpdateHttp _http;
  final Random _random;

  UpdateDevice? _device;
  AppVersion? _current;
  AppVersion? _latest;
  AppVersion? _notified;
  Timer? _timer;
  StreamSubscription<String>? _statuses;

  UpdateStage _stage = UpdateStage.idle;
  UpdateStage get stage => _stage;
  UpdateFailure? _failure;
  UpdateFailure? get failure => _failure;

  /// 0..1 while downloading.
  double? _progress;
  double? get progress => _progress;

  AppVersion? get current => _current;
  AppVersion? get latest => _latest;

  /// This build can update itself (sideloaded Android install).
  bool get supported =>
      _device != null && !installedByStore(_device!.installer);

  /// A newer release was found and isn't installed yet.
  bool get hasUpdate =>
      _latest != null && _current != null && _latest! > _current!;

  Future<void> start() async {
    _device = await _platform.device();
    _current = _device == null ? null : AppVersion.parse(_device!.version);
    notifyListeners();
    if (!supported || _current == null) return;
    _statuses = _platform.statuses.listen(_onStatus);
    // A leftover from an interrupted update is useless now.
    await clearDownloads();
    // First check a few minutes after launch, then about daily.
    _schedule(Duration(minutes: 2 + _random.nextInt(13)));
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, () async {
      await check();
      _schedule(nextCheckIn(_random));
    });
  }

  /// Returns whether a newer version exists. Automatic checks stay silent
  /// on errors (retried next time); manual ones report them.
  Future<bool> check({bool manual = false}) async {
    final current = _current;
    if (!supported || current == null) return false;
    if (!manual && (!_settings.updateChecks || !_ready())) return false;
    if (_stage == UpdateStage.downloading || _stage == UpdateStage.installing) {
      return hasUpdate;
    }
    if (manual) _set(UpdateStage.checking);
    try {
      final location = await _http.redirectOf(latestReleaseUri());
      final latest = location == null ? null : versionFromRedirect(location);
      if (latest == null || !(latest > current)) {
        _latest = null;
        _set(manual ? UpdateStage.upToDate : UpdateStage.idle);
        return false;
      }
      _latest = latest;
      _set(UpdateStage.available);
      if (_notified != latest) {
        _notified = latest;
        final l = _strings();
        await _platform.notify(
          l.updateAvailableTitle,
          l.updateAvailableBody(latest.toString()),
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('WHISPER_UPDATE check failed: $e');
      if (manual) _fail(UpdateFailure.network);
      return false;
    }
  }

  /// Downloads the APK for this phone, verifies it, and starts the install.
  Future<void> install() async {
    final latest = _latest;
    final device = _device;
    if (latest == null || device == null || !hasUpdate) return;
    if (_stage == UpdateStage.downloading || _stage == UpdateStage.installing) {
      return;
    }
    if (!await _platform.canInstall()) {
      // Android's per-app switch; the user comes back and taps again.
      await _platform.openInstallPermission();
      _fail(UpdateFailure.permission);
      return;
    }
    final name = apkName(latest, device.abis);
    final dir = await _platform.downloadDir();
    final file = File('${dir.path}/whisper-update.apk');
    _progress = 0;
    _set(UpdateStage.downloading);
    try {
      final sums = parseSums(
        await _http.text(assetUri(latest, 'SHA256SUMS.txt')),
      );
      final expected = sums[name];
      if (expected == null) throw const FormatException('no checksum');
      await _http.download(
        assetUri(latest, name),
        file,
        onProgress: (received, total) {
          if (total == null || total <= 0) return;
          _progress = received / total;
          notifyListeners();
        },
      );
      final digest = (await sha256.bind(file.openRead()).first).hex();
      if (digest != expected) {
        await _delete(file);
        _fail(UpdateFailure.checksum);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WHISPER_UPDATE download failed: $e');
      await _delete(file);
      _fail(UpdateFailure.network);
      return;
    }
    _progress = null;
    _set(UpdateStage.installing);
    try {
      await _platform.install(file.path, releaseCertSha256);
    } on PlatformException catch (e) {
      await _delete(file);
      _fail(switch (e.code) {
        'bad_signature' || 'not_ours' => UpdateFailure.signature,
        _ => UpdateFailure.install,
      });
    }
  }

  void _onStatus(String status) {
    if (status == 'failed' && _stage == UpdateStage.installing) {
      _fail(UpdateFailure.install);
    }
    // `success` replaces this process; `pending` is Android's own screen.
  }

  /// Downloaded APKs (panic wipe, or after an interrupted update).
  Future<void> clearDownloads() async {
    try {
      final dir = await _platform.downloadDir();
      if (!dir.existsSync()) return;
      for (final f in dir.listSync()) {
        if (f is File && f.path.endsWith('.apk')) await _delete(f);
      }
    } catch (_) {
      // Nothing downloaded, or not on Android.
    }
  }

  Future<void> _delete(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  void _set(UpdateStage stage) {
    _stage = stage;
    if (stage != UpdateStage.failed) _failure = null;
    notifyListeners();
  }

  void _fail(UpdateFailure failure) {
    _progress = null;
    _failure = failure;
    _stage = UpdateStage.failed;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statuses?.cancel();
    super.dispose();
  }
}

/// dart:io client. HttpOverrides.global is TorHttpOverrides in the app, so
/// this goes through Tor, fail-closed like everything else.
class IoUpdateHttp implements UpdateHttp {
  static const _timeout = Duration(seconds: 60);

  HttpClient _client() => HttpClient()
    ..connectionTimeout = _timeout
    ..userAgent = 'Whisper';

  @override
  Future<Uri?> redirectOf(Uri uri) async {
    final client = _client();
    try {
      final request = await client.headUrl(uri).timeout(_timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(_timeout);
      await response.drain<void>();
      final location = response.headers.value(HttpHeaders.locationHeader);
      return location == null ? null : uri.resolve(location);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String> text(Uri uri) async {
    final client = _client();
    try {
      final response = await (await client.getUrl(
        uri,
      )).close().timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 64 * 1024) throw HttpException('too big', uri: uri);
      }
      return String.fromCharCodes(bytes);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> download(
    Uri uri,
    File to, {
    required void Function(int received, int? total) onProgress,
  }) async {
    final client = _client();
    final sink = to.openWrite();
    try {
      final response = await (await client.getUrl(
        uri,
      )).close().timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final total = response.contentLength > 0 ? response.contentLength : null;
      if ((total ?? 0) > maxUpdateBytes) {
        throw HttpException('too big', uri: uri);
      }
      var received = 0;
      await for (final chunk in response.timeout(_timeout)) {
        received += chunk.length;
        if (received > maxUpdateBytes) throw HttpException('too big', uri: uri);
        sink.add(chunk);
        onProgress(received, total);
      }
    } finally {
      await sink.close();
      client.close(force: true);
    }
  }
}

/// No in-app updates (tests, non-Android): the service stays unsupported.
class NoUpdatePlatform implements UpdatePlatform {
  const NoUpdatePlatform();

  @override
  Future<UpdateDevice?> device() async => null;
  @override
  Future<Directory> downloadDir() async => Directory.systemTemp;
  @override
  Future<bool> canInstall() async => false;
  @override
  Future<void> openInstallPermission() async {}
  @override
  Future<void> install(String path, String cert) async {}
  @override
  Future<void> notify(String title, String text) async {}
  @override
  Stream<String> get statuses => const Stream.empty();
}

/// Updater.kt over a method channel.
class PlatformUpdater implements UpdatePlatform {
  static const _channel = MethodChannel('whisper/update');
  final _status = StreamController<String>.broadcast();

  PlatformUpdater() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'status') {
        final status = (call.arguments as Map?)?['status'];
        if (status is String) _status.add(status);
      }
    });
  }

  @override
  Stream<String> get statuses => _status.stream;

  @override
  Future<UpdateDevice?> device() async {
    if (!Platform.isAndroid) return null;
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('info');
      if (info == null) return null;
      return (
        version: info['version'] as String? ?? '',
        abis: [...?(info['abis'] as List?)?.whereType<String>()],
        installer: info['installer'] as String?,
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<Directory> downloadDir() async {
    // App-private cache: no storage permission, wiped with the app.
    final dir = Directory('${Directory.systemTemp.path}/updates');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallPermission() =>
      _channel.invokeMethod<void>('openInstallPermission');

  @override
  Future<void> install(String path, String cert) =>
      _channel.invokeMethod<void>('install', {'path': path, 'cert': cert});

  @override
  Future<void> notify(String title, String text) =>
      _channel.invokeMethod<void>('notify', {'title': title, 'text': text});
}
