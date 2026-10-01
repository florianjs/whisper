import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/logic/identity.dart';

const vector12 =
    'leader monkey parrot ring guide accident before fence cannon height naive bean';
const vector12Pub =
    '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917';

IdentityStore makeStore(KeyVault vault) =>
    IdentityStore(vault, derive: (m) async => deriveIdentity(m));

void main() {
  test('starts empty with an empty vault', () async {
    final store = makeStore(MemoryKeyVault());
    await store.hydrate();
    expect(store.hasIdentity, isFalse);
  });

  test('draft is not persisted until confirmed', () async {
    final vault = MemoryKeyVault();
    final store = makeStore(vault);
    await store.startCreation();
    expect(store.draftMnemonic!.split(' '), hasLength(24));
    expect(store.hasIdentity, isFalse);
    expect(vault.values, isEmpty);

    await store.confirmDraft();
    expect(store.hasIdentity, isTrue);
    expect(store.draftMnemonic, isNull);
    expect(vault.values, isNotEmpty);
  });

  test('discarding during derivation drops the late draft', () async {
    final store = makeStore(MemoryKeyVault());
    final pending = store.startCreation();
    store.discardDraft();
    await pending;
    expect(store.draftMnemonic, isNull);
  });

  test('confirm without draft throws', () {
    final store = makeStore(MemoryKeyVault());
    expect(store.confirmDraft, throwsStateError);
  });

  test('restore persists and survives a new hydrate', () async {
    final vault = MemoryKeyVault();
    await makeStore(vault).restore('  $vector12 ');

    final reopened = makeStore(vault);
    await reopened.hydrate();
    expect(reopened.identity!.publicKey, vector12Pub);
  });

  test('the recovery phrase is never stored', () async {
    final vault = MemoryKeyVault();
    final store = makeStore(vault);
    await store.restore(vector12);
    await store.startCreation();
    await store.confirmDraft();
    for (final value in vault.values.values) {
      expect(value, isNot(contains('mnemonic')));
      expect(value, isNot(contains('leader')));
      expect(value, isNot(contains('monkey')));
    }
  });

  test('migration: a stored phrase from an older version is erased', () async {
    final vault = MemoryKeyVault();
    final id = deriveIdentity(vector12);
    vault.values['identity'] = jsonEncode({
      'mnemonic': vector12,
      'privateKey': id.privateKey,
      'publicKey': id.publicKey,
    });
    final store = makeStore(vault);
    await store.hydrate();
    expect(store.identity!.publicKey, vector12Pub);
    expect(vault.values['identity'], isNot(contains('mnemonic')));
    expect(vault.values['identity'], isNot(contains('leader monkey')));
  });

  test('restore rejects an invalid phrase and writes nothing', () async {
    final vault = MemoryKeyVault();
    final store = makeStore(vault);
    await expectLater(
      store.restore('leader monkey parrot'),
      throwsArgumentError,
    );
    expect(vault.values, isEmpty);
    expect(store.hasIdentity, isFalse);
  });

  test('wipe clears vault and state', () async {
    final vault = MemoryKeyVault();
    final store = makeStore(vault);
    await store.restore(vector12);
    await store.wipe();
    expect(store.hasIdentity, isFalse);
    expect(vault.values, isEmpty);
  });
}
