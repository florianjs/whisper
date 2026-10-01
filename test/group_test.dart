import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/logic/group.dart';

const a = 'aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11';
const b = 'bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22';
const c = 'cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33';

GroupState group({int v = 1, Set<String>? members, String admin = a}) =>
    GroupState(
      id: 'ab' * 16,
      name: 'Famille',
      admin: admin,
      members: members ?? {a, b},
      version: v,
    );

void main() {
  test('state round-trips through a rumor signed by the admin', () {
    final g = group();
    final back = GroupState.fromRumor(g.toRumor(recipient: b))!;
    expect(back.id, g.id);
    expect(back.members, {a, b});
    expect(back.version, 1);
  });

  test('a non-admin cannot publish the group state', () {
    final forged = Nip01Event(
      pubKey: b, // b claims the group whose admin is a
      kind: GroupState.kindState,
      tags: const [],
      content:
          '{"id":"${'ab' * 16}","name":"x","admin":"$a",'
          '"members":["$a","$b"],"v":9}',
      createdAt: 1700000000,
    );
    expect(GroupState.fromRumor(forged), isNull);
  });

  test('malformed states are rejected', () {
    expect(GroupState.fromJson({'id': 'x'}), isNull);
    expect(
      GroupState.fromJson({
        ...group().toJson(),
        'members': [b],
      }),
      isNull,
      reason: 'admin must be a member',
    );
    expect(
      GroupState.fromJson({
        ...group().toJson(),
        'members': [
          for (var i = 0; i < 21; i++) i.toRadixString(16).padLeft(64, '0'),
        ],
      }),
      isNull,
      reason: 'max 20 members',
    );
    expect(GroupState.fromJson({...group().toJson(), 'name': '  '}), isNull);
  });

  test('versions only go up, admin never changes', () {
    expect(shouldApplyGroupState(current: null, incoming: group()), isTrue);
    expect(
      shouldApplyGroupState(current: group(v: 2), incoming: group(v: 3)),
      isTrue,
    );
    expect(
      shouldApplyGroupState(current: group(v: 3), incoming: group(v: 2)),
      isFalse,
      reason: 'replayed old state',
    );
    expect(
      shouldApplyGroupState(
        current: group(v: 1),
        incoming: group(v: 5, admin: c, members: {c, a}),
      ),
      isFalse,
      reason: 'takeover by another admin',
    );
  });

  test('copyWith bumps the version', () {
    final g = group().copyWith(members: {a, b, c});
    expect(g.version, 2);
    expect(g.members, {a, b, c});
  });
}
