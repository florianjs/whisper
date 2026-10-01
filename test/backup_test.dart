import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/backup_service.dart';
import 'package:whisper/logic/backup.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/models/message.dart';

import 'support/fake_network.dart';

BackupService service(Peer p) => BackupService(
  db: p.db,
  identity: p.identity,
  reloaders: [p.messages.reload],
);

void main() {
  test('round trip: same account on a new phone gets its history', () async {
    final net = FakeNetwork();
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'avant');
    await until(() => bob.messages.requests.isNotEmpty);
    await bob.messages.accept(alice.pubkey);
    await bob.messages.send(alice.pubkey, 'réponse');
    await until(() => alice.messages.messagesWith(bob.pubkey).length == 2);

    final bytes = await service(alice).export();
    expect(String.fromCharCodes(bytes), isNot(contains('avant')));

    // New phone, same recovery phrase, relays empty (nothing to replay).
    final phone2 = await makePeer(FakeNetwork(), aliceWords);
    expect(phone2.messages.conversations, isEmpty);
    final added = await service(phone2).import(bytes);
    expect(added, greaterThan(0));
    await until(() => phone2.messages.messagesWith(bob.pubkey).length == 2);
    expect(phone2.messages.isAccepted(bob.pubkey), isTrue);
    expect(phone2.messages.messagesWith(bob.pubkey).map((m) => m.text), [
      'avant',
      'réponse',
    ]);
  });

  test('another account cannot open it', () async {
    final alice = deriveIdentity(aliceWords);
    final bob = deriveIdentity(bobWords);
    final bytes = await encodeBackup(alice, {
      'messages': [
        {'id': 'x', 'text': 'secret'},
      ],
    });
    await expectLater(
      decodeBackup(bob, bytes),
      throwsA(isA<BackupException>().having((e) => e.reason, 'reason', 'key')),
    );
    expect(
      (await decodeBackup(alice, bytes))['messages']!.single['text'],
      'secret',
    );
  });

  test('tampered or foreign files are refused', () async {
    final alice = deriveIdentity(aliceWords);
    final bytes = await encodeBackup(alice, const {});
    final tampered = Uint8List.fromList(bytes)..[bytes.length - 3] ^= 1;
    await expectLater(
      decodeBackup(alice, tampered),
      throwsA(isA<BackupException>().having((e) => e.reason, 'reason', 'key')),
    );
    await expectLater(
      decodeBackup(alice, Uint8List.fromList(List.filled(64, 7))),
      throwsA(
        isA<BackupException>().having((e) => e.reason, 'reason', 'format'),
      ),
    );
  });

  test('import never overwrites what the phone already has', () async {
    final net = FakeNetwork();
    final alice = await makePeer(net, aliceWords);
    await alice.db.putDoc('contacts', {'id': 'bb' * 32, 'state': 'accepted'});
    final bytes = await service(alice).export();

    final phone2 = await makePeer(FakeNetwork(), aliceWords);
    await phone2.db.putDoc('contacts', {'id': 'bb' * 32, 'state': 'blocked'});
    await service(phone2).import(bytes);
    expect(
      (await phone2.db.getDoc('contacts', 'bb' * 32))!['state'],
      'blocked',
    );
  });

  test('device sync markers do not travel', () async {
    final net = FakeNetwork();
    final alice = await makePeer(net, aliceWords);
    await alice.db.putDoc('meta', {'id': 'inbox_sync', 'listeningAt': 1});
    final data = await decodeBackup(
      alice.identity.identity!,
      await service(alice).export(),
    );
    expect(data.containsKey('meta'), isFalse);
    expect(MessageStatus.values, isNotEmpty);
  });
}
