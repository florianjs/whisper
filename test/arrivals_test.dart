import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/group_store.dart';
import 'package:whisper/models/message.dart';

import 'support/fake_network.dart';

void main() {
  test(
    'DM arrivals: new incoming only, replays and own messages silent',
    () async {
      final net = FakeNetwork();
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      final got = <Message>[];
      bob.messages.arrivals.listen(got.add);
      final mine = <Message>[];
      alice.messages.arrivals.listen(mine.add);

      await alice.messages.send(bob.pubkey, 'salut');
      await until(() => got.isNotEmpty);
      expect(got.single.text, 'salut');

      bob.transport.replay(); // relay hands everything again
      await quiet();
      expect(got, hasLength(1));
      expect(mine, isEmpty, reason: 'own messages are not arrivals');
    },
  );

  test('group arrivals: active groups only', () async {
    final net = FakeNetwork();
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    GroupStore groups(Peer p) => GroupStore(
      identity: p.identity,
      db: p.db,
      transport: p.transport,
      messages: p.messages,
    );
    final ga = groups(alice), gb = groups(bob);
    await pumpEventQueue();
    final got = <Message>[];
    gb.arrivals.listen(got.add);

    // Alice isn't Bob's contact: the invite is pending, nothing to notify.
    final id = (await ga.create('G', {bob.pubkey}))!;
    await until(() => gb.group(id) != null);
    await ga.send(id, 'un');
    await quiet();
    expect(got, isEmpty);

    await gb.accept(id);
    await ga.send(id, 'deux');
    await until(() => got.isNotEmpty);
    expect(got.single.text, 'deux');
  });
}
