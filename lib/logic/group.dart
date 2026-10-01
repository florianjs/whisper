import 'dart:convert';
import 'dart:math';

import 'package:ndk/ndk.dart' show Nip01Event;

/// A private group (v1): no server, no relay-side membership. Every message
/// is gift-wrapped once per member, so relays can't even tell a group exists.
/// Only the admin (creator) can change the name or the members; everyone
/// applies the admin's latest [version].
class GroupState {
  const GroupState({
    required this.id,
    required this.name,
    required this.admin,
    required this.members,
    required this.version,
  });

  static const maxMembers = 20;

  /// 32 random hex chars, stable for the group's life.
  final String id;
  final String name;

  /// Hex pubkey of the creator; always a member.
  final String admin;

  /// Hex pubkeys, admin included.
  final Set<String> members;
  final int version;

  static String newId([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  GroupState copyWith({String? name, Set<String>? members}) => GroupState(
    id: id,
    name: name ?? this.name,
    admin: admin,
    members: members ?? this.members,
    version: version + 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'admin': admin,
    'members': (members.toList()..sort()),
    'v': version,
  };

  static final _hex32 = RegExp(r'^[0-9a-f]{32}$');
  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Null for anything malformed (untrusted input).
  static GroupState? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], admin = json['admin'];
    final members = json['members'], v = json['v'];
    if (id is! String || !_hex32.hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty || name.length > 60) {
      return null;
    }
    if (admin is! String || !_hex64.hasMatch(admin)) return null;
    if (members is! List || members.length > maxMembers) return null;
    if (v is! int || v < 1) return null;
    final set = <String>{};
    for (final m in members) {
      if (m is! String || !_hex64.hasMatch(m)) return null;
      set.add(m);
    }
    if (!set.contains(admin)) return null;
    return GroupState(
      id: id,
      name: name.trim(),
      admin: admin,
      members: set,
      version: v,
    );
  }

  /// Rumor kind carrying a group's state. Never published unwrapped.
  static const kindState = 14447;

  /// Rumor kind a member sends the admin to leave the group.
  static const kindLeave = 14448;

  /// Tag marking a chat rumor (kind 14) as belonging to a group.
  static const groupTag = 'g';

  Nip01Event toRumor({required String recipient}) => Nip01Event(
    pubKey: admin,
    kind: kindState,
    tags: [
      ['p', recipient],
    ],
    content: jsonEncode(toJson()),
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );

  static GroupState? fromRumor(Nip01Event rumor) {
    if (rumor.kind != kindState) return null;
    try {
      final state = fromJson(jsonDecode(rumor.content));
      // Only the admin can publish its group's state.
      if (state == null || state.admin != rumor.pubKey) return null;
      return state;
    } catch (_) {
      return null;
    }
  }
}

/// Whether an incoming state should replace what we hold. The admin can't
/// change (it's bound to the group id at creation), versions only go up.
bool shouldApplyGroupState({
  required GroupState? current,
  required GroupState incoming,
}) {
  if (current == null) return true;
  if (incoming.admin != current.admin) return false;
  return incoming.version > current.version;
}

/// Group id carried by a chat rumor, or null for a 1:1 message.
String? groupIdOf(Nip01Event rumor) {
  for (final t in rumor.tags) {
    if (t.length > 1 && t[0] == GroupState.groupTag) return t[1];
  }
  return null;
}
