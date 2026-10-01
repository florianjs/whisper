import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/account_wiper.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/logic/identity.dart';

const vector12 =
    'leader monkey parrot ring guide accident before fence cannon height naive bean';

/// Records every destructive call in [log]; can be told to fail.
class RecordingVault extends MemoryKeyVault {
  RecordingVault(this.log, {this.failDeletes = false});
  final List<String> log;
  final bool failDeletes;

  @override
  Future<void> delete(String key) async {
    log.add('vault.delete:$key');
    if (failDeletes) throw Exception('keystore unavailable');
    await super.delete(key);
  }
}

class RecordingDocStore extends MemoryDocStore {
  RecordingDocStore(this.log, {this.failDestroy = false});
  final List<String> log;
  final bool failDestroy;

  @override
  Future<void> destroy() async {
    log.add('db.destroy');
    if (failDestroy) throw Exception('disk error');
    await super.destroy();
  }
}

void main() {
  late List<String> log;

  Future<(AccountWiper, IdentityStore, RecordingVault, RecordingDocStore)>
  setup({bool failDeletes = false, bool failDestroy = false}) async {
    log = [];
    final vault = RecordingVault(log, failDeletes: failDeletes);
    final db = RecordingDocStore(log, failDestroy: failDestroy);
    final identity = IdentityStore(
      vault,
      derive: (m) async => deriveIdentity(m),
    );
    await identity.restore(vector12);
    await vault.write(Db.keyName, 'k');
    await vault.write('tor_mode', 'off');
    await vault.write('tor_disguise', 'on');
    await vault.write('tor_level', 'snowflake');
    await db.putDoc('messages', {'id': 'm1', 'text': 'secret'});
    final wiper = AccountWiper(
      vault: vault,
      db: db,
      identity: identity,
      clearClipboard: () async => log.add('clipboard.clear'),
    );
    return (wiper, identity, vault, db);
  }

  test('erases keys, identity, messages and clipboard', () async {
    final (wiper, identity, vault, db) = await setup();
    final errors = await wiper.panic();

    expect(errors, isEmpty);
    expect(identity.hasIdentity, isFalse);
    expect(vault.values, isEmpty);
    expect(await db.listDocs('messages'), isEmpty);
    expect(log, contains('clipboard.clear'));
  });

  test('destroys the DB key before touching the DB file', () async {
    final (wiper, _, _, _) = await setup();
    await wiper.panic();
    expect(
      log.indexOf('vault.delete:${Db.keyName}'),
      lessThan(log.indexOf('db.destroy')),
    );
    expect(log.first, 'vault.delete:${Db.keyName}');
  });

  test('keystore failure still logs out and still deletes the DB', () async {
    final (wiper, identity, _, db) = await setup(failDeletes: true);
    final errors = await wiper.panic();

    expect(errors, isNotEmpty);
    expect(identity.hasIdentity, isFalse);
    expect(db.destroyCount, 1);
    expect(log, contains('clipboard.clear'));
  });

  test('DB failure does not stop the remaining steps', () async {
    final (wiper, identity, vault, _) = await setup(failDestroy: true);
    final errors = await wiper.panic();

    expect(errors, hasLength(1));
    expect(identity.hasIdentity, isFalse);
    expect(vault.values, isEmpty);
    expect(log, contains('clipboard.clear'));
  });

  AccountWiper withNetwork(
    IdentityStore identity,
    RecordingVault vault,
    RecordingDocStore db, {
    required Future<void> Function() vanish,
  }) => AccountWiper(
    vault: vault,
    db: db,
    identity: identity,
    clearClipboard: () async => log.add('clipboard.clear'),
    requestVanish: vanish,
    clearNetworkState: () async => log.add('network.clear'),
    vanishTimeout: const Duration(milliseconds: 200),
  );

  test(
    'asks relays to vanish after the DB key, while the identity exists',
    () async {
      final (_, identity, vault, db) = await setup();
      var hadIdentity = false;
      final wiper = withNetwork(
        identity,
        vault,
        db,
        vanish: () async {
          hadIdentity = identity.hasIdentity;
          log.add('vanish');
        },
      );
      final errors = await wiper.panic();
      expect(errors, isEmpty);
      expect(hadIdentity, isTrue, reason: 'the request must be signed');
      expect(
        log.indexOf('vault.delete:${Db.keyName}'),
        lessThan(log.indexOf('vanish')),
      );
      expect(log.indexOf('vanish'), lessThan(log.indexOf('db.destroy')));
      expect(log, contains('network.clear'));
    },
  );

  test('an offline or hanging vanish request never blocks the wipe', () async {
    final (_, identity, vault, db) = await setup();
    final never = withNetwork(
      identity,
      vault,
      db,
      vanish: () => Completer<void>().future,
    );
    final started = DateTime.now();
    final errors = await never.panic();
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 2)),
    );
    expect(errors, hasLength(1), reason: 'timeout reported, rest done');
    expect(identity.hasIdentity, isFalse);
    expect(await db.listDocs('messages'), isEmpty);

    final (_, identity2, vault2, db2) = await setup();
    final failing = withNetwork(
      identity2,
      vault2,
      db2,
      vanish: () async => throw StateError('offline'),
    );
    await failing.panic();
    expect(identity2.hasIdentity, isFalse);
    expect(log, contains('network.clear'));
  });
}
