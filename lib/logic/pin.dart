import 'package:ndk/ndk.dart' show Nip01Event;

/// The message pinned at the top of a conversation, shared with the other
/// side (chat), the members (group) or the followers (channel). One per
/// conversation; the latest pin or unpin wins.
class Pin {
  const Pin(this.messageId, this.at);

  /// Null: unpinned.
  final String? messageId;

  /// created_at of the pin event (seconds).
  final int at;

  /// Rumor kind, gift-wrapped like a chat message: relays never see a pin.
  static const kindRumor = 14450;

  /// Whether [incoming] replaces [current]. Same second: the larger id wins,
  /// so both sides settle on the same pin whatever order they got them in.
  static bool newer(Pin? current, Pin incoming) {
    if (current == null) return true;
    if (incoming.at != current.at) return incoming.at > current.at;
    return (incoming.messageId ?? '').compareTo(current.messageId ?? '') > 0;
  }

  Map<String, Object?> toJson() => {'message': messageId, 'at': at};

  static Pin? fromJson(Map<String, dynamic>? d) {
    final at = d?['at'];
    if (at is! int) return null;
    final id = d?['message'];
    return Pin(id is String ? id : null, at);
  }

  /// Rumor pinning [messageId] (null unpins) for [to]; [extraTags] carry the
  /// group tag. Never published unwrapped.
  static Nip01Event rumor({
    required String sender,
    required List<String> to,
    required String? messageId,
    List<List<String>> extraTags = const [],
    int? createdAt,
  }) => Nip01Event(
    pubKey: sender,
    kind: kindRumor,
    tags: [
      for (final p in to) ['p', p],
      ...extraTags,
      if (messageId != null) ['e', messageId],
    ],
    content: '',
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );

  /// From a pin rumor; null if it isn't one, or if the id isn't 64 hex
  /// (rumor and event ids are).
  static Pin? fromRumor(Nip01Event rumor) {
    if (rumor.kind != kindRumor) return null;
    String? id;
    for (final t in rumor.tags) {
      if (t.length > 1 && t[0] == 'e') id = t[1];
    }
    if (id != null && !_hex64.hasMatch(id)) return null;
    return Pin(id, rumor.createdAt);
  }

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');
}
