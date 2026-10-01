import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/pin_crypto.dart';

/// Tiny cost so tests stay fast; production uses the OWASP defaults.
KdfParams cheap() => KdfParams.fresh(memoryKiB: 64, iterations: 1);

void main() {
  test('same PIN + salt → same key; different PIN or salt → different', () {
    final p = cheap();
    final a = deriveKek(('482913', p));
    expect(a, hasLength(32));
    expect(deriveKek(('482913', p)), a);
    expect(deriveKek(('482914', p)), isNot(a));
    expect(deriveKek(('482913', cheap())), isNot(a));
  });

  test('production cost is at least the OWASP Argon2id minimum', () {
    final p = KdfParams.fresh();
    expect(p.memoryKiB, greaterThanOrEqualTo(19 * 1024));
    expect(p.iterations, greaterThanOrEqualTo(2));
    expect(p.salt, hasLength(16));
  });

  test('seal / open round trip; wrong key or tampering → null', () async {
    final p = cheap();
    final key = deriveKek(('482913', p));
    final secrets = {'identity': '{"privateKey":"aa"}', 'db_key': 'bb'};
    final sealed = await seal(key, secrets);
    expect(sealed, isNot(contains('privateKey')));
    expect(await openSealed(key, sealed), secrets);

    expect(await openSealed(deriveKek(('000001', p)), sealed), isNull);
    final bytes = Uint8List.fromList(sealed.codeUnits);
    bytes[20] = bytes[20] == 65 ? 66 : 65;
    expect(await openSealed(key, String.fromCharCodes(bytes)), isNull);
    expect(await openSealed(key, 'not base64 !!'), isNull);
  });

  test('two seals of the same data differ (random nonce)', () async {
    final key = deriveKek(('482913', cheap()));
    expect(await seal(key, {'a': 'b'}), isNot(await seal(key, {'a': 'b'})));
  });

  test('PIN rules', () {
    expect(isAcceptablePin('482913'), isTrue);
    expect(isAcceptablePin('48291'), isFalse, reason: 'too short');
    expect(isAcceptablePin('48a913'), isFalse, reason: 'digits only');
    expect(isAcceptablePin('000000'), isFalse);
    expect(isAcceptablePin('123456'), isFalse);
    expect(isAcceptablePin('987654'), isFalse);
    expect(isAcceptablePin('4829134829'), isTrue);
  });

  test('lockout grows after 5 failures and caps at 1 h', () {
    expect(lockoutFor(4), Duration.zero);
    expect(lockoutFor(5), const Duration(seconds: 30));
    expect(lockoutFor(6), const Duration(seconds: 60));
    expect(lockoutFor(20), const Duration(hours: 1));
  });
}
