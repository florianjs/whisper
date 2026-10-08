import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart' show BytesUtils;
import 'package:cryptography/cryptography.dart';
import 'package:ndk/ndk.dart' show Bip340EventSigner, Nip01Event;
import 'package:ndk/shared/nips/nip01/bip340.dart';

import 'identity.dart';
import 'relays.dart';

/// Broadcast channels (v1): only the admin posts (and edits), viewers react.
///
/// A channel is a keypair (signs posts and metadata) plus a symmetric
/// content key. Everything published is AES-256-GCM encrypted with that key,
/// so relays never read a channel, public or private. Both keys derive from
/// the admin's identity key: restoring the account restores the channels.
abstract final class Channel {
  static const kindPost = 4470;
  static const kindReaction = 4471;

  /// A new text for one of the channel's posts; the latest one wins.
  static const kindEdit = 4472;

  /// The post pinned at the top of the channel; empty id unpins.
  static const kindPin = 4473;

  /// Replaceable (NIP-01 10000–19999): relays keep the latest only.
  static const kindMeta = 14470;

  /// Gift-wrapped rumor carrying an invite to a contact.
  static const kindInvite = 14449;

  /// Own channels probed on restore.
  static const recoverScan = 10;

  static const maxName = 60;
  static const maxAbout = 280;
  static const maxPost = 4000;

  /// Reactions are picked, never typed: no free-form text from viewers.
  static const emojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static bool isHex64(Object? s) => s is String && _hex64.hasMatch(s);
}

final _hmac = Hmac.sha256();

Future<Uint8List> _derive(String identitySk, String label) async {
  final mac = await _hmac.calculateMac(
    utf8.encode(label),
    secretKey: SecretKey(BytesUtils.fromHexString(identitySk)),
  );
  return Uint8List.fromList(mac.bytes);
}

// secp256k1 group order.
final _n = BigInt.parse(
  'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
  radix: 16,
);

/// Keys of the [index]-th channel owned by [owner].
class ChannelKeys {
  const ChannelKeys({
    required this.privateKey,
    required this.publicKey,
    required this.contentKey,
  });

  final String privateKey;
  final String publicKey;

  /// 32 bytes, hex.
  final String contentKey;

  static Future<ChannelKeys> derive(Identity owner, int index) async {
    var counter = 0;
    while (true) {
      final raw = await _derive(
        owner.privateKey,
        'whisper/channel/v1/sk/$index/$counter',
      );
      final x = BigInt.parse(BytesUtils.toHexString(raw), radix: 16);
      // Out of range with probability ~2^-128; retry keeps it well-defined.
      if (x == BigInt.zero || x >= _n) {
        counter++;
        continue;
      }
      final sk = BytesUtils.toHexString(raw);
      final key = await _derive(
        owner.privateKey,
        'whisper/channel/v1/key/$index',
      );
      return ChannelKeys(
        privateKey: sk,
        publicKey: Bip340.getPublicKey(sk),
        contentKey: BytesUtils.toHexString(key),
      );
    }
  }
}

/// Per-channel key a viewer signs reactions with. Derived, so a restored
/// account keeps its reactions (no double count), yet unlinkable to the
/// identity by anyone without its private key.
Future<({String privateKey, String publicKey})> reactionKey(
  Identity viewer,
  String channelPk,
) async {
  var counter = 0;
  while (true) {
    final raw = await _derive(
      viewer.privateKey,
      'whisper/channel/v1/react/$channelPk/$counter',
    );
    final x = BigInt.parse(BytesUtils.toHexString(raw), radix: 16);
    if (x == BigInt.zero || x >= _n) {
      counter++;
      continue;
    }
    final sk = BytesUtils.toHexString(raw);
    return (privateKey: sk, publicKey: Bip340.getPublicKey(sk));
  }
}

final _aes = AesGcm.with256bits();

/// Binds a ciphertext to its channel and kind: a post can't be replayed as
/// metadata or in another channel.
List<int> _aad(String channelPk, int kind) => utf8.encode('$channelPk:$kind');

Future<String> encryptFor(
  String contentKey,
  String channelPk,
  int kind,
  Map<String, Object?> payload,
) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(payload)),
    secretKey: SecretKey(BytesUtils.fromHexString(contentKey)),
    aad: _aad(channelPk, kind),
  );
  return base64Encode(box.concatenation());
}

/// Null for anything that doesn't decrypt to a JSON object.
Future<Map<String, Object?>?> decryptFor(
  String contentKey,
  String channelPk,
  int kind,
  String content,
) async {
  try {
    final box = SecretBox.fromConcatenation(
      base64Decode(content),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final clear = await _aes.decrypt(
      box,
      secretKey: SecretKey(BytesUtils.fromHexString(contentKey)),
      aad: _aad(channelPk, kind),
    );
    final json = jsonDecode(utf8.decode(clear));
    return json is Map<String, Object?> ? json : null;
  } catch (_) {
    return null;
  }
}

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Future<Nip01Event> _sign(
  String sk,
  String pk,
  int kind,
  String content, {
  List<List<String>> tags = const [],
  int? createdAt,
}) => Bip340EventSigner(privateKey: sk, publicKey: pk).sign(
  Nip01Event(
    pubKey: pk,
    kind: kind,
    tags: tags,
    content: content,
    createdAt: createdAt ?? _now(),
  ),
);

Future<Nip01Event> signPost(
  ChannelKeys keys,
  String text, {
  int? createdAt,
}) async => _sign(
  keys.privateKey,
  keys.publicKey,
  Channel.kindPost,
  await encryptFor(keys.contentKey, keys.publicKey, Channel.kindPost, {
    't': text,
  }),
  createdAt: createdAt,
);

Future<Nip01Event> signMeta(
  ChannelKeys keys,
  ChannelMeta meta, {
  int? createdAt,
}) async => _sign(
  keys.privateKey,
  keys.publicKey,
  Channel.kindMeta,
  await encryptFor(
    keys.contentKey,
    keys.publicKey,
    Channel.kindMeta,
    meta.toJson(),
  ),
  createdAt: createdAt,
);

/// The post id is inside the ciphertext, like for reactions.
Future<Nip01Event> signEdit(
  ChannelKeys keys,
  String postId,
  String text, {
  int? createdAt,
}) async => _sign(
  keys.privateKey,
  keys.publicKey,
  Channel.kindEdit,
  await encryptFor(keys.contentKey, keys.publicKey, Channel.kindEdit, {
    'e': postId,
    't': text,
  }),
  createdAt: createdAt,
);

/// [postId] null unpins. Inside the ciphertext, like for edits.
Future<Nip01Event> signPin(
  ChannelKeys keys,
  String? postId, {
  int? createdAt,
}) async => _sign(
  keys.privateKey,
  keys.publicKey,
  Channel.kindPin,
  await encryptFor(keys.contentKey, keys.publicKey, Channel.kindPin, {
    'e': postId ?? '',
  }),
  createdAt: createdAt,
);

/// [emoji] empty retracts. The post id is inside the ciphertext: relays only
/// see that someone reacted somewhere in the channel.
Future<Nip01Event> signReaction({
  required ({String privateKey, String publicKey}) key,
  required String channelPk,
  required String contentKey,
  required String postId,
  required String emoji,
  int? createdAt,
}) async => _sign(
  key.privateKey,
  key.publicKey,
  Channel.kindReaction,
  await encryptFor(contentKey, channelPk, Channel.kindReaction, {
    'e': postId,
    'r': emoji,
  }),
  tags: [
    ['p', channelPk],
  ],
  createdAt: createdAt,
);

class ChannelMeta {
  const ChannelMeta({
    required this.name,
    this.about = '',
    required this.public,
    this.fullHistory = true,
  });

  final String name;
  final String about;

  /// Public: anyone holding the invite may share it (link / QR). Private:
  /// invites only go to contacts the admin picks.
  final bool public;

  /// True: new followers see past posts, which the admin's phone keeps on
  /// the relays. False: followers only see what was posted after they
  /// joined, and old posts fade from the relays. Not enforced by crypto:
  /// the read key still opens whatever a relay kept.
  final bool fullHistory;

  Map<String, Object?> toJson() => {
    'n': name,
    'a': about,
    'p': public,
    'h': fullHistory,
  };

  @override
  bool operator ==(Object other) =>
      other is ChannelMeta &&
      other.name == name &&
      other.about == about &&
      other.public == public &&
      other.fullHistory == fullHistory;

  @override
  int get hashCode => Object.hash(name, about, public, fullHistory);

  /// Channels from before the choice existed have no 'h': full history.
  static ChannelMeta? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final name = json['n'], about = json['a'] ?? '', public = json['p'];
    final history = json['h'] ?? true;
    if (name is! String || name.trim().isEmpty) return null;
    if (name.length > Channel.maxName) return null;
    if (about is! String || about.length > Channel.maxAbout) return null;
    if (public is! bool || history is! bool) return null;
    return ChannelMeta(
      name: name.trim(),
      about: about,
      public: public,
      fullHistory: history,
    );
  }
}

/// Everything a viewer needs to follow a channel.
class ChannelInvite {
  const ChannelInvite({
    required this.channelPk,
    required this.contentKey,
    required this.name,
    required this.public,
    this.relays = const [],
    this.fullHistory = true,
  });

  final String channelPk;
  final String contentKey;
  final String name;
  final bool public;
  final List<String> relays;

  /// [ChannelMeta.fullHistory], known before the metadata arrives: no
  /// glimpse of earlier posts in a "from when they follow" channel.
  final bool fullHistory;

  static const prefix = 'whisper-channel:';

  Map<String, Object?> toJson() => {
    'v': 1,
    'pk': channelPk,
    'k': contentKey,
    'n': name,
    'p': public,
    'r': relays,
    'h': fullHistory,
  };

  String encode() =>
      prefix +
      base64Url.encode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '');

  static ChannelInvite? fromJson(Object? json) {
    if (json is! Map) return null;
    final pk = json['pk'], key = json['k'], name = json['n'];
    final public = json['p'], relays = json['r'] ?? const [];
    final history = json['h'] ?? true;
    if (json['v'] != 1 || history is! bool) return null;
    if (!Channel.isHex64(pk) || !Channel.isHex64(key)) return null;
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > Channel.maxName) {
      return null;
    }
    if (public is! bool || relays is! List || relays.length > 8) return null;
    return ChannelInvite(
      channelPk: pk as String,
      contentKey: key as String,
      name: name.trim(),
      public: public,
      relays: [
        for (final r in relays)
          if (r is String) ?normalizeRelayUrl(r),
      ],
      fullHistory: history,
    );
  }

  static ChannelInvite? parse(String text) {
    final t = text.trim();
    if (!t.startsWith(prefix)) return null;
    try {
      var b = t.substring(prefix.length);
      b += '=' * ((4 - b.length % 4) % 4);
      return fromJson(jsonDecode(utf8.decode(base64Url.decode(b))));
    } catch (_) {
      return null;
    }
  }
}

/// Reaction counts per post. [reactions] maps post id → reactor → latest
/// (emoji, createdAt); empty emoji = retracted.
Map<String, int> countReactions(
  Map<String, ({String emoji, int at})> byReactor,
) {
  final counts = <String, int>{};
  for (final r in byReactor.values) {
    if (r.emoji.isEmpty) continue;
    counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
  }
  return counts;
}

/// Whether [incoming] replaces [current] for one reactor on one post.
bool newerReaction(({String emoji, int at})? current, int incomingAt) =>
    current == null || incomingAt > current.at;
