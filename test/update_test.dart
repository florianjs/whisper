import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/update.dart';

void main() {
  group('AppVersion', () {
    test('parses tags, plain versions and build numbers', () {
      expect(AppVersion.parse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.parse('1.2.3+45'), const AppVersion(1, 2, 3));
      expect(AppVersion.parse(' 10.0.1 '), const AppVersion(10, 0, 1));
    });

    test('rejects anything else', () {
      for (final bad in [
        '',
        'v1.2',
        '1.2.3.4',
        'v1.2.3-beta',
        'latest',
        'v-1.2.3',
      ]) {
        expect(AppVersion.parse(bad), isNull, reason: bad);
      }
    });

    test('orders numerically, not as text', () {
      expect(AppVersion.parse('1.10.0')! > AppVersion.parse('1.9.9')!, isTrue);
      expect(AppVersion.parse('2.0.0')! > AppVersion.parse('1.99.99')!, isTrue);
      expect(AppVersion.parse('1.0.0')! > AppVersion.parse('1.0.0')!, isFalse);
      expect(const AppVersion(1, 2, 3).tag, 'v1.2.3');
    });
  });

  group('versionFromRedirect', () {
    test('reads the tag of our latest release', () {
      expect(
        versionFromRedirect(
          Uri.parse('https://github.com/florianjs/whisper/releases/tag/v1.4.0'),
        ),
        const AppVersion(1, 4, 0),
      );
    });

    test('no release yet, or a redirect elsewhere: nothing', () {
      for (final url in [
        'https://github.com/florianjs/whisper/releases',
        'https://github.com/someone/whisper/releases/tag/v9.9.9',
        'https://evil.example/florianjs/whisper/releases/tag/v9.9.9',
        'https://github.com/florianjs/whisper/releases/tag/nightly',
      ]) {
        expect(versionFromRedirect(Uri.parse(url)), isNull, reason: url);
      }
    });
  });

  group('apkName', () {
    const v = AppVersion(1, 4, 0);
    test('first supported ABI with its own build', () {
      expect(
        apkName(v, ['arm64-v8a', 'armeabi-v7a', 'armeabi']),
        'whisper-v1.4.0-arm64-v8a.apk',
      );
      expect(
        apkName(v, ['armeabi-v7a', 'armeabi']),
        'whisper-v1.4.0-armeabi-v7a.apk',
      );
      expect(apkName(v, ['x86_64', 'arm64-v8a']), 'whisper-v1.4.0-x86_64.apk');
    });

    test('unknown ABI: the universal APK', () {
      expect(apkName(v, ['riscv64']), 'whisper-v1.4.0.apk');
      expect(apkName(v, []), 'whisper-v1.4.0.apk');
    });

    test('asset URL', () {
      expect(
        assetUri(v, 'SHA256SUMS.txt').toString(),
        'https://github.com/florianjs/whisper/releases/download/v1.4.0/SHA256SUMS.txt',
      );
    });
  });

  test('parseSums reads shasum output, ignores junk', () {
    final a = 'A' * 64;
    final b = 'b' * 64;
    final sums = parseSums(
      '$a  whisper-v1.0.0.apk\n$b *whisper-v1.0.0-arm64-v8a.apk\nnope\n\n',
    );
    expect(sums, {
      'whisper-v1.0.0.apk': 'a' * 64,
      'whisper-v1.0.0-arm64-v8a.apk': b,
    });
  });

  test('checks about once a day, never at a fixed time', () {
    final random = Random(1);
    final delays = List.generate(50, (_) => nextCheckIn(random));
    for (final d in delays) {
      expect(d, greaterThanOrEqualTo(const Duration(hours: 20)));
      expect(d, lessThan(const Duration(hours: 28)));
    }
    expect(delays.toSet().length, greaterThan(40));
  });

  test('store installs update through their store', () {
    expect(installedByStore('com.android.vending'), isTrue);
    expect(installedByStore('org.fdroid.fdroid'), isTrue);
    expect(installedByStore('com.android.chrome'), isFalse);
    expect(installedByStore(null), isFalse);
  });

  test('pinned certificate matches the published one', () {
    final published = File(
      'release/signing-cert-sha256.txt',
    ).readAsStringSync().trim().replaceAll(':', '').toLowerCase();
    expect(releaseCertSha256, published);
  });
}
