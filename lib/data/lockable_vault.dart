import 'dart:convert';

import 'package:blockchain_utils/blockchain_utils.dart' show QuickCrypto;
import 'package:flutter/foundation.dart';

import '../logic/pin_crypto.dart';
import 'key_vault.dart';

class VaultLockedException implements Exception {
  const VaultLockedException();
}

enum UnlockOutcome { ok, wrongPin, lockedOut, duress }

class UnlockResult {
  const UnlockResult(this.outcome, [this.retryAfter = Duration.zero]);
  final UnlockOutcome outcome;
  final Duration retryAfter;
}

/// Biometric-gated secret slot (Android Keystore key requiring biometric
/// auth for every use, invalidated when a new fingerprint/face is enrolled).
abstract class BiometricKeyStore {
  Future<bool> isAvailable();

  /// Prompts too: the Keystore key needs a biometric auth to encrypt.
  Future<bool> store(
    String secret, {
    required String title,
    required String cancel,
  });

  /// Prompts the user; null if cancelled, failed, or the key was invalidated.
  Future<String?> read({required String title, required String cancel});
  Future<void> delete();
}

typedef KekDerivation = Future<Uint8List> Function(String pin, KdfParams p);

/// [KeyVault] whose sensitive entries (account key, DB key) are sealed with a
/// key derived from the user's PIN when the app lock is on. Unlocked, they
/// live in memory only; locked, reading them throws — never returns null, so
/// nothing can mistake "locked" for "no key" and start over.
class LockableVault extends ChangeNotifier implements KeyVault {
  LockableVault(
    this._inner, {
    BiometricKeyStore? biometrics,
    KekDerivation? derive,
    KdfParams Function()? newParams,
    DateTime Function()? now,
  }) : _biometrics = biometrics,
       _derive = derive ?? ((pin, p) => compute(deriveKek, (pin, p))),
       _newParams = newParams ?? KdfParams.fresh,
       _now = now ?? DateTime.now;

  static const protectedKeys = {'identity', 'db_key'};
  static const _lockKey = 'lock';
  static const _attemptsKey = 'lock_attempts';
  static const _duressKey = 'lock_duress';
  static const _timeoutKey = 'lock_timeout';

  final KeyVault _inner;
  final BiometricKeyStore? _biometrics;
  final KekDerivation _derive;
  final KdfParams Function() _newParams;
  final DateTime Function() _now;

  bool _enabled = false;
  bool _bio = false;
  bool _hasDuress = false;
  Duration _autoLock = Duration.zero;
  KdfParams? _params;
  String? _sealed;
  Uint8List? _kek;
  Map<String, String>? _secrets;

  bool get isEnabled => _enabled;
  bool get isLocked => _enabled && _secrets == null;
  bool get biometricsEnabled => _enabled && _bio;
  bool get hasDuress => _hasDuress;

  /// Time in background before locking. Not a secret: stored in the clear.
  Duration get autoLockAfter => _autoLock;

  Future<void> setAutoLockAfter(Duration d) async {
    _autoLock = d;
    await _inner.write(_timeoutKey, '${d.inSeconds}');
    notifyListeners();
  }

  Future<void> init() async {
    final raw = await _inner.read(_lockKey);
    _hasDuress = await _inner.read(_duressKey) != null;
    _autoLock = Duration(
      seconds: int.tryParse(await _inner.read(_timeoutKey) ?? '') ?? 0,
    );
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _params = KdfParams.fromJson(json['kdf'] as Map<String, dynamic>);
    _sealed = json['sealed'] as String;
    _bio = json['bio'] == true;
    _enabled = true;
    _secrets = null;
  }

  // --- KeyVault -----------------------------------------------------------

  @override
  Future<String?> read(String key) async {
    if (!_enabled || !protectedKeys.contains(key)) return _inner.read(key);
    final secrets = _secrets;
    if (secrets == null) throw const VaultLockedException();
    return secrets[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (!_enabled || !protectedKeys.contains(key)) {
      return _inner.write(key, value);
    }
    final secrets = _secrets;
    if (secrets == null) throw const VaultLockedException();
    secrets[key] = value;
    await _reseal();
  }

  @override
  Future<void> delete(String key) async {
    if (!_enabled || !protectedKeys.contains(key)) return _inner.delete(key);
    final secrets = _secrets;
    // Only the panic wipe deletes protected keys; locked (duress, sign-out
    // from the lock screen) there's nothing to reseal: erase it all.
    if (secrets == null) return deleteAll();
    secrets.remove(key);
    await _reseal();
  }

  /// Panic: every secret and every lock artefact, biometric slot included.
  Future<void> deleteAll() async {
    for (final key in [...protectedKeys, _lockKey, _attemptsKey, _duressKey]) {
      await _inner.delete(key);
    }
    try {
      await _biometrics?.delete();
    } catch (_) {}
    _enabled = false;
    _bio = false;
    _hasDuress = false;
    _params = null;
    _sealed = null;
    _kek = null;
    _secrets = null;
    notifyListeners();
  }

  // --- Lock lifecycle -----------------------------------------------------

  /// Moves the protected entries out of plain storage, sealed under [pin].
  Future<void> enable(String pin) async {
    if (_enabled) throw StateError('already enabled');
    if (!isAcceptablePin(pin)) throw ArgumentError('weak pin');
    final secrets = <String, String>{};
    for (final key in protectedKeys) {
      final value = await _inner.read(key);
      if (value != null) secrets[key] = value;
    }
    _params = _newParams();
    _kek = await _derive(pin, _params!);
    _secrets = secrets;
    _enabled = true;
    await _reseal();
    // Sealed copy written first; only then drop the plain ones.
    for (final key in protectedKeys) {
      await _inner.delete(key);
    }
    notifyListeners();
  }

  Future<UnlockResult> unlock(String pin) async {
    if (!_enabled) return const UnlockResult(UnlockOutcome.ok);
    final wait = await _remainingLockout();
    if (wait > Duration.zero) {
      return UnlockResult(UnlockOutcome.lockedOut, wait);
    }
    final kek = await _derive(pin, _params!);
    final opened = await openSealed(kek, _sealed!);
    // Always pay for the duress check too, so response time doesn't reveal
    // whether a duress PIN exists or which one was typed.
    final isDuress = await _matchesDuress(pin);
    if (opened != null) {
      _kek = kek;
      _secrets = opened;
      await _inner.delete(_attemptsKey);
      notifyListeners();
      return const UnlockResult(UnlockOutcome.ok);
    }
    if (isDuress) return const UnlockResult(UnlockOutcome.duress);
    return _recordFailure();
  }

  /// Re-checks the PIN while unlocked (before disabling the lock), without
  /// touching lock state. Failures count toward the lockout like on the lock
  /// screen, so this can't be used to brute-force either.
  Future<UnlockResult> verifyPin(String pin) async {
    _requireUnlocked();
    final wait = await _remainingLockout();
    if (wait > Duration.zero) {
      return UnlockResult(UnlockOutcome.lockedOut, wait);
    }
    final opened = await openSealed(await _derive(pin, _params!), _sealed!);
    if (opened != null) {
      await _inner.delete(_attemptsKey);
      return const UnlockResult(UnlockOutcome.ok);
    }
    return _recordFailure();
  }

  Future<UnlockResult> _recordFailure() async {
    final failures = (await _failures()) + 1;
    final until = _now().add(lockoutFor(failures));
    await _inner.write(
      _attemptsKey,
      jsonEncode({'n': failures, 'until': until.millisecondsSinceEpoch}),
    );
    return UnlockResult(UnlockOutcome.wrongPin, lockoutFor(failures));
  }

  Future<bool> unlockWithBiometrics({
    required String title,
    required String cancel,
  }) async {
    final bio = _biometrics;
    if (!biometricsEnabled || bio == null) return false;
    final secret = await bio.read(title: title, cancel: cancel);
    if (secret == null) return false;
    final kek = base64Decode(secret);
    final opened = await openSealed(kek, _sealed!);
    if (opened == null) return false;
    _kek = kek;
    _secrets = opened;
    await _inner.delete(_attemptsKey);
    notifyListeners();
    return true;
  }

  /// Forgets every secret held in memory.
  void lock() {
    if (!_enabled || _secrets == null) return;
    _secrets = null;
    _kek = null;
    notifyListeners();
  }

  Future<void> changePin(String newPin) async {
    _requireUnlocked();
    if (!isAcceptablePin(newPin)) throw ArgumentError('weak pin');
    if (await _matchesDuress(newPin)) throw ArgumentError('same as duress');
    _params = _newParams();
    _kek = await _derive(newPin, _params!);
    // The biometric slot holds the old key: drop it, the user re-enables.
    if (_bio) {
      try {
        await _biometrics?.delete();
      } catch (_) {}
      _bio = false;
    }
    await _reseal();
    notifyListeners();
  }

  /// Back to plain Keystore storage (no PIN).
  Future<void> disable() async {
    final secrets = _requireUnlocked();
    for (final e in secrets.entries) {
      await _inner.write(e.key, e.value);
    }
    for (final key in [_lockKey, _attemptsKey, _duressKey]) {
      await _inner.delete(key);
    }
    try {
      await _biometrics?.delete();
    } catch (_) {}
    _enabled = false;
    _bio = false;
    _hasDuress = false;
    _params = null;
    _sealed = null;
    _kek = null;
    _secrets = null;
    notifyListeners();
  }

  Future<bool> biometricsAvailable() async =>
      await _biometrics?.isAvailable() ?? false;

  /// Returns whether biometrics are on afterwards (the user may cancel).
  Future<bool> setBiometrics(
    bool on, {
    String title = '',
    String cancel = '',
  }) async {
    _requireUnlocked();
    final bio = _biometrics;
    if (bio == null) return false;
    if (on) {
      final ok = await bio.store(
        base64Encode(_kek!),
        title: title,
        cancel: cancel,
      );
      if (!ok) return _bio;
    } else {
      await bio.delete();
    }
    _bio = on;
    await _reseal();
    notifyListeners();
    return _bio;
  }

  /// A second PIN that, typed on the lock screen, silently erases everything.
  Future<void> setDuressPin(String pin) async {
    _requireUnlocked();
    if (!isAcceptablePin(pin)) throw ArgumentError('weak pin');
    final real = await openSealed(await _derive(pin, _params!), _sealed!);
    if (real != null) throw ArgumentError('same as real pin');
    final params = _newParams();
    final verifier = _hash(await _derive(pin, params));
    await _inner.write(
      _duressKey,
      jsonEncode({'kdf': params.toJson(), 'v': verifier}),
    );
    _hasDuress = true;
    notifyListeners();
  }

  Future<void> removeDuressPin() async {
    _requireUnlocked();
    await _inner.delete(_duressKey);
    _hasDuress = false;
    notifyListeners();
  }

  // --- internals ----------------------------------------------------------

  Map<String, String> _requireUnlocked() {
    final secrets = _secrets;
    if (!_enabled || secrets == null) throw const VaultLockedException();
    return secrets;
  }

  Future<void> _reseal() async {
    _sealed = await seal(_kek!, _secrets!);
    await _inner.write(
      _lockKey,
      jsonEncode({'kdf': _params!.toJson(), 'sealed': _sealed, 'bio': _bio}),
    );
  }

  Future<bool> _matchesDuress(String pin) async {
    final raw = await _inner.read(_duressKey);
    if (raw == null) return false;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final params = KdfParams.fromJson(json['kdf'] as Map<String, dynamic>);
    return _hash(await _derive(pin, params)) == json['v'];
  }

  static String _hash(Uint8List key) =>
      base64Encode(QuickCrypto.sha256Hash(key));

  Future<int> _failures() async {
    final raw = await _inner.read(_attemptsKey);
    if (raw == null) return 0;
    return (jsonDecode(raw) as Map<String, dynamic>)['n'] as int;
  }

  Future<Duration> _remainingLockout() async {
    final raw = await _inner.read(_attemptsKey);
    if (raw == null) return Duration.zero;
    final until = DateTime.fromMillisecondsSinceEpoch(
      (jsonDecode(raw) as Map<String, dynamic>)['until'] as int,
    );
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }
}
