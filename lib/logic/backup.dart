import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart' show BytesUtils;
import 'package:cryptography/cryptography.dart';

import 'identity.dart';

/// Encrypted history backups.
///
/// The key derives from the identity key: only the same account — restored
/// from its recovery phrase on any phone — can open a backup. Nothing else is
/// needed (no password to forget), and a stolen file is useless without the
/// phrase. Format: magic ‖ nonce ‖ AES-256-GCM(gzip(JSON)).
abstract final class Backup {
  static const magic = [0x57, 0x42, 0x4b, 0x01, 0x8a, 0x3c, 0x5e, 0x11];

  /// Per-device state that must not travel (sync markers, published relay
  /// list). Everything else is history or preferences.
  static const collections = [
    'messages',
    'contacts',
    'contact_info',
    'images',
    'groups',
    'group_messages',
    'channels',
    'channel_posts',
    'channel_reactions',
    'profile',
    'avatars',
    'profile_sent',
    'settings',
  ];
}

class BackupException implements Exception {
  const BackupException(this.reason);

  /// `format`: not a Whisper backup. `key`: another account's backup, or
  /// damaged. `version`: made by a newer Whisper.
  final String reason;

  @override
  String toString() => 'BackupException($reason)';
}

final _aes = AesGcm.with256bits();

Future<SecretKey> _key(Identity id) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('whisper/backup/v1'),
    secretKey: SecretKey(BytesUtils.fromHexString(id.privateKey)),
  );
  return SecretKey(mac.bytes);
}

Future<Uint8List> encodeBackup(
  Identity owner,
  Map<String, List<Map<String, dynamic>>> collections, {
  DateTime? now,
}) async {
  final plain = gzip.encode(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'owner': owner.publicKey,
        'created': (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
        'collections': collections,
      }),
    ),
  );
  final box = await _aes.encrypt(
    plain,
    secretKey: await _key(owner),
    aad: Backup.magic,
  );
  return Uint8List.fromList([...Backup.magic, ...box.concatenation()]);
}

Future<Map<String, List<Map<String, dynamic>>>> decodeBackup(
  Identity owner,
  Uint8List bytes,
) async {
  const m = Backup.magic;
  if (bytes.length < m.length + 28) throw const BackupException('format');
  for (var i = 0; i < m.length; i++) {
    if (bytes[i] != m[i]) throw const BackupException('format');
  }
  final List<int> clear;
  try {
    final box = SecretBox.fromConcatenation(
      bytes.sublist(m.length),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    clear = await _aes.decrypt(box, secretKey: await _key(owner), aad: m);
  } catch (_) {
    throw const BackupException('key');
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(gzip.decode(clear)));
  } catch (_) {
    throw const BackupException('format');
  }
  if (json is! Map) throw const BackupException('format');
  if (json['v'] != 1) throw const BackupException('version');
  if (json['owner'] != owner.publicKey) throw const BackupException('key');
  final raw = json['collections'];
  if (raw is! Map) throw const BackupException('format');
  return {
    for (final name in Backup.collections)
      if (raw[name] is List)
        name: [
          for (final d in raw[name] as List)
            if (d is Map && d['id'] is String) d.cast<String, dynamic>(),
        ],
  };
}
