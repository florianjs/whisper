import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hashlib/hashlib.dart' show Argon2, Argon2Type;

/// Argon2id cost. OWASP minimum is m=19 MiB, t=2, p=1; each guess costs an
/// attacker that much memory and time, which is what makes a 6-digit PIN
/// survive an offline dump of the vault.
class KdfParams {
  const KdfParams({
    required this.salt,
    this.memoryKiB = 19 * 1024,
    this.iterations = 2,
  });

  final Uint8List salt;
  final int memoryKiB;
  final int iterations;

  static KdfParams fresh({int memoryKiB = 19 * 1024, int iterations = 2}) {
    final r = Random.secure();
    return KdfParams(
      salt: Uint8List.fromList(List.generate(16, (_) => r.nextInt(256))),
      memoryKiB: memoryKiB,
      iterations: iterations,
    );
  }

  Map<String, dynamic> toJson() => {
    'salt': base64Encode(salt),
    'm': memoryKiB,
    't': iterations,
  };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    salt: base64Decode(json['salt'] as String),
    memoryKiB: json['m'] as int,
    iterations: json['t'] as int,
  );
}

/// PIN → 32-byte key-encryption key. Deliberately slow: run via `compute`.
Uint8List deriveKek((String, KdfParams) args) {
  final (pin, params) = args;
  return Argon2(
    type: Argon2Type.argon2id,
    salt: params.salt,
    hashLength: 32,
    iterations: params.iterations,
    parallelism: 1,
    memorySizeKB: params.memoryKiB,
  ).convert(utf8.encode(pin)).bytes;
}

final _aes = AesGcm.with256bits();

/// AES-256-GCM, random nonce: base64(nonce ‖ ciphertext ‖ tag).
Future<String> seal(Uint8List key, Map<String, String> secrets) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(secrets)),
    secretKey: SecretKey(key),
  );
  return base64Encode(box.concatenation());
}

/// Null when the key is wrong or the data was tampered with (GCM tag).
Future<Map<String, String>?> openSealed(Uint8List key, String sealed) async {
  try {
    final box = SecretBox.fromConcatenation(
      base64Decode(sealed),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key));
    return (jsonDecode(utf8.decode(clear)) as Map).cast<String, String>();
  } on SecretBoxAuthenticationError {
    return null;
  } catch (_) {
    return null;
  }
}

/// PIN rules: digits only (entered on Whisper's own keypad, never the system
/// keyboard), 6 to 12 of them, not trivially guessable.
bool isAcceptablePin(String pin) {
  if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return false; // 000000
  const asc = '01234567890123456789';
  const desc = '98765432109876543210';
  if (asc.contains(pin) || desc.contains(pin)) return false; // 123456, 654321
  return true;
}

/// Wait imposed after [failures] consecutive wrong PINs: none for the first
/// 4, then 30 s doubling up to 1 h. On top of Argon2's per-guess cost.
Duration lockoutFor(int failures) {
  if (failures < 5) return Duration.zero;
  final seconds = 30 * pow(2, failures - 5).toInt();
  return Duration(seconds: min(seconds, 3600));
}
