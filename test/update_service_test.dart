import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashlib/hashlib.dart' show sha256;
import 'package:whisper/data/db.dart';
import 'package:whisper/data/settings_store.dart';
import 'package:whisper/data/update_service.dart';
import 'package:whisper/l10n/app_localizations.dart';
import 'package:whisper/logic/update.dart';

const tagUrl = 'https://github.com/florianjs/whisper/releases/tag/';

class FakeHttp implements UpdateHttp {
  String latest = '${tagUrl}v1.1.0';
  List<int> apk = List.generate(5000, (i) => i % 251);
  String? sumsOverride;
  bool fail = false;
  final requested = <Uri>[];

  String get apkSha => sha256.convert(apk).hex();

  @override
  Future<Uri?> redirectOf(Uri uri) async {
    requested.add(uri);
    if (fail) throw const SocketException('no network');
    return Uri.parse(latest);
  }

  @override
  Future<String> text(Uri uri) async {
    requested.add(uri);
    if (fail) throw const SocketException('no network');
    return sumsOverride ??
        '$apkSha  whisper-v1.1.0-arm64-v8a.apk\n'
            '${'0' * 64}  whisper-v1.1.0.apk\n';
  }

  @override
  Future<void> download(
    Uri uri,
    File to, {
    required void Function(int received, int? total) onProgress,
  }) async {
    requested.add(uri);
    if (fail) throw const SocketException('no network');
    await to.writeAsBytes(apk);
    onProgress(apk.length, apk.length);
  }
}

class FakePlatform implements UpdatePlatform {
  FakePlatform(this.dir);
  final Directory dir;
  String version = '1.0.0';
  String? installer = 'com.android.chrome';
  bool canInstallApps = true;
  String? rejectWith;
  final installs = <(String, String)>[];
  final notifications = <String>[];
  int permissionPrompts = 0;
  final status = StreamController<String>.broadcast(sync: true);

  @override
  Future<UpdateDevice?> device() async => (
    version: version,
    abis: const ['arm64-v8a', 'armeabi-v7a'],
    installer: installer,
  );

  @override
  Future<Directory> downloadDir() async => dir;

  @override
  Future<bool> canInstall() async => canInstallApps;

  @override
  Future<void> openInstallPermission() async => permissionPrompts++;

  @override
  Future<void> install(String path, String cert) async {
    if (rejectWith != null) throw PlatformException(code: rejectWith!);
    installs.add((path, cert));
  }

  @override
  Future<void> notify(String title, String text) async =>
      notifications.add(text);

  @override
  Stream<String> get statuses => status.stream;
}

void main() {
  late Directory dir;
  late FakeHttp http;
  late FakePlatform platform;
  late SettingsStore settings;
  late bool ready;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('whisper_update_test');
    http = FakeHttp();
    platform = FakePlatform(dir);
    settings = SettingsStore(MemoryDocStore());
    ready = true;
  });

  tearDown(() => dir.delete(recursive: true));

  Future<UpdateService> make() async {
    final s = UpdateService(
      settings: settings,
      platform: platform,
      http: http,
      ready: () => ready,
      strings: () => lookupAppLocalizations(const Locale('en')),
    );
    await s.start();
    addTearDown(s.dispose);
    return s;
  }

  group('check', () {
    test('a newer release: available, notified once per version', () async {
      final s = await make();
      expect(await s.check(), isTrue);
      expect(s.stage, UpdateStage.available);
      expect(s.latest, const AppVersion(1, 1, 0));
      expect(platform.notifications, ['Whisper 1.1.0 is ready to install.']);

      await s.check();
      expect(platform.notifications, hasLength(1));
    });

    test('same or older version, or no release yet: nothing', () async {
      final s = await make();
      for (final latest in [
        '${tagUrl}v1.0.0',
        '${tagUrl}v0.9.9',
        'https://github.com/florianjs/whisper/releases',
      ]) {
        http.latest = latest;
        expect(await s.check(), isFalse, reason: latest);
      }
      expect(s.stage, UpdateStage.idle);
      expect(await s.check(manual: true), isFalse);
      expect(s.stage, UpdateStage.upToDate);
      expect(platform.notifications, isEmpty);
    });

    test('setting off or app locked: automatic checks stay home', () async {
      final s = await make();
      await settings.setUpdateChecks(false);
      expect(await s.check(), isFalse);
      await settings.setUpdateChecks(true);
      ready = false;
      expect(await s.check(), isFalse);
      expect(http.requested, isEmpty);

      // The user asking is another matter.
      expect(await s.check(manual: true), isTrue);
    });

    test('store installs are left to their store', () async {
      platform.installer = 'org.fdroid.fdroid';
      final s = await make();
      expect(s.supported, isFalse);
      expect(await s.check(manual: true), isFalse);
      expect(http.requested, isEmpty);
    });

    test(
      'network errors: silent when automatic, reported when asked',
      () async {
        final s = await make();
        http.fail = true;
        await s.check();
        expect(s.stage, UpdateStage.idle);
        await s.check(manual: true);
        expect(s.stage, UpdateStage.failed);
        expect(s.failure, UpdateFailure.network);
      },
    );
  });

  group('install', () {
    test('downloads the APK for this ABI, verified, then installs', () async {
      final s = await make();
      await s.check();
      await s.install();

      expect(
        http.requested.last.path,
        '/florianjs/whisper/releases/download/v1.1.0/whisper-v1.1.0-arm64-v8a.apk',
      );
      expect(platform.installs, hasLength(1));
      final (path, cert) = platform.installs.single;
      expect(cert, releaseCertSha256);
      expect(File(path).readAsBytesSync(), http.apk);
      expect(s.stage, UpdateStage.installing);
    });

    test('checksum mismatch: deleted, never installed', () async {
      final s = await make();
      await s.check();
      http.sumsOverride = '${'f' * 64}  whisper-v1.1.0-arm64-v8a.apk\n';
      await s.install();
      expect(s.failure, UpdateFailure.checksum);
      expect(platform.installs, isEmpty);
      expect(dir.listSync().whereType<File>(), isEmpty);
    });

    test('no checksum for our file: refused', () async {
      final s = await make();
      await s.check();
      http.sumsOverride = '${'f' * 64}  something-else.apk\n';
      await s.install();
      expect(s.stage, UpdateStage.failed);
      expect(platform.installs, isEmpty);
    });

    test('Android refuses the signature: reported, file deleted', () async {
      final s = await make();
      await s.check();
      platform.rejectWith = 'bad_signature';
      await s.install();
      expect(s.failure, UpdateFailure.signature);
      expect(dir.listSync().whereType<File>(), isEmpty);
    });

    test('no install permission yet: asks for it, downloads nothing', () async {
      final s = await make();
      await s.check();
      platform.canInstallApps = false;
      final before = http.requested.length;
      await s.install();
      expect(platform.permissionPrompts, 1);
      expect(s.failure, UpdateFailure.permission);
      expect(http.requested.length, before);
    });

    test('nothing newer: install does nothing', () async {
      http.latest = '${tagUrl}v1.0.0';
      final s = await make();
      await s.check();
      await s.install();
      expect(platform.installs, isEmpty);
    });

    test('installer reports failure', () async {
      final s = await make();
      await s.check();
      await s.install();
      platform.status.add('failed');
      expect(s.failure, UpdateFailure.install);
    });
  });

  test('clearDownloads removes downloaded APKs', () async {
    final s = await make();
    File('${dir.path}/whisper-update.apk').writeAsBytesSync([1, 2, 3]);
    await s.clearDownloads();
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('settings: update checks on by default, persisted, reset', () async {
    final db = MemoryDocStore();
    final a = SettingsStore(db);
    expect(a.updateChecks, isTrue);
    await a.setUpdateChecks(false);
    final b = SettingsStore(db);
    await b.hydrate();
    expect(b.updateChecks, isFalse);
    b.reset();
    expect(b.updateChecks, isTrue);
  });
}
