import 'dart:typed_data';

import '../logic/backup.dart';
import 'db.dart';
import 'identity_store.dart';

/// Export / import of the encrypted history (see logic/backup.dart).
class BackupService {
  BackupService({
    required DocStore db,
    required IdentityStore identity,
    required List<void Function()> reloaders,
  }) : _db = db,
       _identity = identity,
       _reloaders = reloaders;

  final DocStore _db;
  final IdentityStore _identity;
  final List<void Function()> _reloaders;

  /// Collections whose list order follows the message time.
  static const _timed = {'messages', 'group_messages', 'channel_posts'};

  Future<Uint8List> export() async {
    final me = _identity.identity;
    if (me == null) throw StateError('locked');
    return encodeBackup(me, {
      for (final c in Backup.collections) c: await _db.listDocs(c),
    });
  }

  /// Adds what this phone doesn't have yet; never overwrites (a contact
  /// blocked here since the backup stays blocked). Returns how many
  /// documents were added. Throws [BackupException].
  Future<int> import(Uint8List bytes) async {
    final me = _identity.identity;
    if (me == null) throw StateError('locked');
    final data = await decodeBackup(me, bytes);
    var added = 0;
    for (final MapEntry(key: collection, value: docs) in data.entries) {
      for (final doc in docs) {
        if (_identity.identity != me) return added; // wiped meanwhile
        if (await _db.getDoc(collection, doc['id'] as String) != null) {
          continue;
        }
        final at = doc['createdAt'];
        await _db.putDoc(
          collection,
          doc,
          updatedAt: _timed.contains(collection) && at is int
              ? at * 1000
              : null,
        );
        added++;
      }
    }
    for (final reload in _reloaders) {
      reload();
    }
    return added;
  }
}
