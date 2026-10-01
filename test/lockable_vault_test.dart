import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/lockable_vault.dart';
import 'package:whisper/logic/pin_crypto.dart';

class FakeBiometrics implements BiometricKeyStore {
  String? slot;
  bool userAccepts = true;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> store(
    String secret, {
    required String title,
    required String cancel,
  }) async {
    if (!userAccepts) return false;
    slot = secret;
    return true;
  }

  @override
  Future<String?> read({required String title, required String cancel}) async =>
      userAccepts ? slot : null;
  @override
  Future<void> delete() async => slot = null;
}

const pin = '482913';
const identityJson = '{"privateKey":"aa11","publicKey":"bb22"}';

void main() {
  late MemoryKeyVault inner;
  late FakeBiometrics bio;
  late DateTime now;

  LockableVault make() => LockableVault(
    inner,
    biometrics: bio,
    derive: (p, params) async => deriveKek((p, params)),
    newParams: () => KdfParams.fresh(memoryKiB: 64, iterations: 1),
    now: () => now,
  );

  setUp(() async {
    inner = MemoryKeyVault();
    bio = FakeBiometrics();
    now = DateTime(2026, 9, 30);
    await inner.write('identity', identityJson);
    await inner.write('db_key', 'k' * 64);
  });

  Future<LockableVault> enabled() async {
    final v = make();
    await v.init();
    await v.enable(pin);
    return v;
  }

  /// Simulates an app restart: fresh instance over the same storage.
  Future<LockableVault> restart() async {
    final v = make();
    await v.init();
    return v;
  }

  test('enabling removes every plaintext secret from storage', () async {
    await enabled();
    expect(inner.values.containsKey('identity'), isFalse);
    expect(inner.values.containsKey('db_key'), isFalse);
    final everything = inner.values.values.join();
    expect(everything, isNot(contains('aa11')));
    expect(everything, isNot(contains('k' * 64)));
  });

  test('locked after restart: protected reads THROW (never null)', () async {
    await enabled();
    final v = await restart();
    expect(v.isLocked, isTrue);
    expect(() => v.read('identity'), throwsA(isA<VaultLockedException>()));
    expect(() => v.read('db_key'), throwsA(isA<VaultLockedException>()));
  });

  test('a locked vault can never make the DB regenerate its key', () async {
    await enabled();
    final v = await restart();
    final db = Db(v, directory: () async => '/nonexistent');
    await expectLater(
      db.getDoc('meta', 'schema'),
      throwsA(isA<VaultLockedException>()),
    );
    expect(inner.values.containsKey('db_key'), isFalse, reason: 'no new key');
  });

  test('right PIN unlocks; wrong PIN does not', () async {
    await enabled();
    final v = await restart();
    expect((await v.unlock('111222')).outcome, UnlockOutcome.wrongPin);
    expect(v.isLocked, isTrue);
    expect((await v.unlock(pin)).outcome, UnlockOutcome.ok);
    expect(await v.read('identity'), identityJson);
    expect(await v.read('db_key'), 'k' * 64);
  });

  test('writes while unlocked are sealed and survive a restart', () async {
    final v = await enabled();
    await v.write('db_key', 'new-key');
    final again = await restart();
    await again.unlock(pin);
    expect(await again.read('db_key'), 'new-key');
    expect(inner.values.values.join(), isNot(contains('new-key')));
  });

  test('lock() forgets secrets from memory', () async {
    final v = await enabled();
    v.lock();
    expect(v.isLocked, isTrue);
    expect(() => v.read('identity'), throwsA(isA<VaultLockedException>()));
  });

  test('escalating lockout after 5 wrong PINs, survives restart', () async {
    await enabled();
    var v = await restart();
    for (var i = 0; i < 4; i++) {
      expect((await v.unlock('111222')).retryAfter, Duration.zero);
    }
    final fifth = await v.unlock('111222');
    expect(fifth.retryAfter, const Duration(seconds: 30));

    v = await restart(); // killing the app doesn't reset the counter
    final blocked = await v.unlock(pin);
    expect(blocked.outcome, UnlockOutcome.lockedOut);
    expect(v.isLocked, isTrue, reason: 'even the right PIN waits');

    now = now.add(const Duration(seconds: 31));
    expect((await v.unlock(pin)).outcome, UnlockOutcome.ok);
    // Success resets the counter.
    v.lock();
    expect((await v.unlock('111222')).retryAfter, Duration.zero);
  });

  test('duress PIN is reported, and cannot equal the real PIN', () async {
    final v = await enabled();
    await expectLater(v.setDuressPin(pin), throwsArgumentError);
    await v.setDuressPin('739104');
    expect(v.hasDuress, isTrue);

    final locked = await restart();
    expect((await locked.unlock('739104')).outcome, UnlockOutcome.duress);
    expect((await locked.unlock(pin)).outcome, UnlockOutcome.ok);
  });

  test('deleteAll (panic / duress) erases every trace', () async {
    final v = await enabled();
    await v.setDuressPin('739104');
    await v.setBiometrics(true);
    final locked = await restart();
    await locked.deleteAll();
    expect(inner.values, isEmpty);
    expect(bio.slot, isNull);
    expect(locked.isEnabled, isFalse);
  });

  test('deleting a protected key while locked wipes everything', () async {
    await enabled();
    final v = await restart();
    await v.delete('db_key'); // what the panic wiper does first
    expect(inner.values, isEmpty);
  });

  test('biometrics unlock; refusal or invalidated slot falls back', () async {
    final v = await enabled();
    await v.setBiometrics(true);
    expect(bio.slot, isNotNull);

    var locked = await restart();
    expect(locked.biometricsEnabled, isTrue);
    expect(await locked.unlockWithBiometrics(title: 't', cancel: 'c'), isTrue);
    expect(await locked.read('identity'), identityJson);

    locked = await restart();
    bio.userAccepts = false;
    expect(await locked.unlockWithBiometrics(title: 't', cancel: 'c'), isFalse);
    expect(locked.isLocked, isTrue);

    // New fingerprint enrolled → OS invalidates the key → PIN required.
    bio
      ..userAccepts = true
      ..slot = null;
    expect(await locked.unlockWithBiometrics(title: 't', cancel: 'c'), isFalse);
    expect((await locked.unlock(pin)).outcome, UnlockOutcome.ok);
  });

  test('change PIN: old one stops working, biometric shortcut reset', () async {
    final v = await enabled();
    await v.setBiometrics(true);
    await v.changePin('604817');
    expect(v.biometricsEnabled, isFalse);
    expect(bio.slot, isNull, reason: 'old key copy removed');
    final locked = await restart();
    expect((await locked.unlock(pin)).outcome, UnlockOutcome.wrongPin);
    expect((await locked.unlock('604817')).outcome, UnlockOutcome.ok);
  });

  test('cancelling the biometric prompt keeps biometrics off', () async {
    final v = await enabled();
    bio.userAccepts = false;
    expect(await v.setBiometrics(true), isFalse);
    expect(v.biometricsEnabled, isFalse);
  });

  test('disable puts secrets back in plain Keystore storage', () async {
    final v = await enabled();
    await v.disable();
    expect(inner.values['identity'], identityJson);
    expect(inner.values.containsKey('lock'), isFalse);
    final plain = await restart();
    expect(plain.isEnabled, isFalse);
    expect(await plain.read('identity'), identityJson);
  });

  test('weak PINs are refused', () async {
    final v = make();
    await v.init();
    await expectLater(v.enable('123456'), throwsArgumentError);
    expect(v.isEnabled, isFalse);
  });

  test('verifyPin checks without locking, and counts failures', () async {
    final v = await enabled();
    expect((await v.verifyPin(pin)).outcome, UnlockOutcome.ok);
    expect(v.isLocked, isFalse);
    for (var i = 0; i < 4; i++) {
      await v.verifyPin('111222');
    }
    expect(
      (await v.verifyPin('111222')).retryAfter,
      const Duration(seconds: 30),
    );
    expect((await v.verifyPin(pin)).outcome, UnlockOutcome.lockedOut);
    expect(v.isLocked, isFalse);
  });
}
