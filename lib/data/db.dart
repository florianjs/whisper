import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'key_vault.dart';

/// Document store: JSON blobs keyed by (collection, id). Abstract so stores
/// can be unit-tested with [MemoryDocStore].
abstract class DocStore {
  /// [updatedAt] overrides the sort key, which [listDocs] orders on. Pass the
  /// document's existing value for rewrites that shouldn't reorder the list.
  Future<void> putDoc(
    String collection,
    Map<String, dynamic> doc, {
    int? updatedAt,
  });
  Future<Map<String, dynamic>?> getDoc(String collection, String id);
  Future<List<Map<String, dynamic>>> listDocs(String collection);
  Future<void> deleteDoc(String collection, String id);

  /// Closes and deletes the underlying storage. The next call reopens a fresh,
  /// empty store.
  Future<void> destroy();
}

/// SQLCipher-backed [DocStore]. The passphrase is 32 random bytes kept in the
/// [KeyVault], never derived from the user's seed: destroying that one vault
/// entry makes the file unreadable (crypto-shredding) even if flash storage
/// keeps remnants of it after deletion.
class Db implements DocStore {
  Db(this._vault, {Future<String> Function()? directory})
    : _directory = directory ?? getDatabasesPath;

  static const keyName = 'db_key';

  /// Not secret: marks a DB already rekeyed to the raw-key format.
  static const rawFlagName = 'db_key_raw';
  static const fileName = 'whisper.db';

  final KeyVault _vault;
  final Future<String> Function() _directory;
  Future<Database>? _db;

  Future<String> get path async => p.join(await _directory(), fileName);

  Future<Database> _open() => _db ??= _openFresh();

  Future<Database> _openFresh() async {
    final file = await path;
    var key = await _vault.read(keyName);
    if (key == null) {
      // No key means any existing file is unreadable leftovers (e.g. an
      // interrupted wipe). Start clean rather than failing to open.
      await deleteDatabase(file);
      key = _randomKey();
      await _vault.write(keyName, key);
      await _vault.write(rawFlagName, '1');
    }
    // The key is already 256 random bits, so SQLCipher's passphrase KDF
    // (PBKDF2, 256k iterations — seconds of frozen UI on slow phones, since
    // sqflite keys on Android's main thread) adds nothing. The `x'…'` form
    // makes SQLCipher use it as the raw key and skip the KDF.
    final rawKey = "x'$key'";
    if (await _vault.read(rawFlagName) != '1' && await databaseExists(file)) {
      // One-time migration of a DB created with the passphrase form.
      try {
        final legacy = await openDatabase(file, password: key);
        await legacy.execute('PRAGMA rekey = "$rawKey";');
        await legacy.close();
      } catch (_) {
        // Already rekeyed by a run killed before the flag was saved: the
        // passphrase no longer opens it, the raw key below will.
      }
    }
    await _vault.write(rawFlagName, '1');
    return openDatabase(
      file,
      password: rawKey,
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS documents (
            collection TEXT NOT NULL,
            id TEXT NOT NULL,
            data TEXT NOT NULL,
            updatedAt INTEGER NOT NULL,
            PRIMARY KEY (collection, id)
          );
        ''');
        // Schema/migration bookkeeping, same role as intervals' meta doc.
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert('documents', {
          'collection': 'meta',
          'id': 'schema',
          'data': jsonEncode({'id': 'schema', 'version': 1, 'migrations': []}),
          'updatedAt': now,
        });
      },
    );
  }

  static String _randomKey() {
    final rng = Random.secure();
    return List.generate(
      32,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Future<void> putDoc(
    String collection,
    Map<String, dynamic> doc, {
    int? updatedAt,
  }) async {
    final db = await _open();
    await db.insert('documents', {
      'collection': collection,
      'id': doc['id'],
      'data': jsonEncode(doc),
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async {
    final db = await _open();
    final rows = await db.query(
      'documents',
      columns: ['data'],
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> listDocs(String collection) async {
    final db = await _open();
    final rows = await db.query(
      'documents',
      columns: ['data'],
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  @override
  Future<void> deleteDoc(String collection, String id) async {
    final db = await _open();
    await db.delete(
      'documents',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
  }

  /// Closes the connection (app lock) — the file and its key stay intact.
  Future<void> close() async {
    final pending = _db;
    _db = null;
    if (pending == null) return;
    try {
      await (await pending).close();
    } catch (_) {}
  }

  @override
  Future<void> destroy() async {
    final pending = _db;
    _db = null;
    if (pending != null) {
      try {
        await (await pending).close();
      } catch (_) {
        // A DB that failed to open has nothing to close; deletion still runs.
      }
    }
    final file = await path;
    await deleteDatabase(file);
    // deleteDatabase covers the main file; make sure WAL side files go too.
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final f = File('$file$suffix');
      if (await f.exists()) await f.delete();
    }
  }
}

class MemoryDocStore implements DocStore {
  final Map<String, Map<String, (int, Map<String, dynamic>)>> _data = {};
  int destroyCount = 0;

  /// Test helper: synchronous peek at a collection.
  Iterable<Map<String, dynamic>> values(String collection) =>
      _data[collection]?.values.map((e) => e.$2) ?? const [];

  @override
  Future<void> putDoc(
    String collection,
    Map<String, dynamic> doc, {
    int? updatedAt,
  }) async {
    _data.putIfAbsent(collection, () => {})[doc['id'] as String] = (
      updatedAt ?? DateTime.now().microsecondsSinceEpoch,
      doc,
    );
  }

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async =>
      _data[collection]?[id]?.$2;

  @override
  Future<List<Map<String, dynamic>>> listDocs(String collection) async {
    final entries = (_data[collection]?.values.toList() ?? [])
      ..sort((a, b) => b.$1.compareTo(a.$1));
    return entries.map((e) => e.$2).toList();
  }

  @override
  Future<void> deleteDoc(String collection, String id) async =>
      _data[collection]?.remove(id);

  @override
  Future<void> destroy() async {
    destroyCount++;
    _data.clear();
  }
}
