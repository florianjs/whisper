import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart' show visibleForTesting;

import 'package:ndk/ndk.dart'
    show
        Bip340EventSigner,
        Bip340EventVerifier,
        Nip01Event,
        Nip01EventModel,
        Nip01Utils;
import 'package:ndk/shared/nips/nip01/bip340.dart';

import 'identity.dart';

/// NIP-17 private direct messages over NIP-59 gift wraps, implemented on
/// ndk's primitives only (NIP-44, BIP-340). ndk's own GiftWrap use case
/// skips the rumor/seal author check below and caches decrypted payloads, so
/// the whole pipeline lives here, pure and transport-agnostic.
class Nip17 {
  Nip17._();

  static const kindChat = 14;
  static const kindReaction = 7;
  static const kindSeal = 13;
  static const kindGiftWrap = 1059;

  /// Seal and wrap timestamps are pushed up to 2 days into the past so relays
  /// can't correlate them with the real send time.
  static const _jitterSeconds = 2 * 24 * 3600;
  static final _random = Random.secure();

  /// Checks run in an isolate so decrypting a burst of messages doesn't
  /// jank the UI. Widget tests swap in `useIsolate: false`: ndk's isolate
  /// manager is a singleton bound to the first test's zone.
  @visibleForTesting
  static Bip340EventVerifier verifier = Bip340EventVerifier();

  /// Id + BIP-340 signature check for plain signed events (channels).
  static Future<bool> verifySigned(Nip01Event event) => verifier.verify(event);

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
  static int _jittered(int t) => t - _random.nextInt(_jitterSeconds) - 1;

  /// The message [rumor] replies to (NIP-10 style `e` tag marked "reply"),
  /// if it names a well-formed id.
  static String? replyIdOf(Nip01Event rumor) {
    for (final t in rumor.tags) {
      if (t.length > 3 && t[0] == 'e' && t[3] == 'reply') {
        return _hex64.hasMatch(t[1]) ? t[1] : null;
      }
    }
    return null;
  }

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Unsigned kind-14 message. Its id is what both sides store and what
  /// reactions/replies reference; it never travels in clear.
  static Nip01Event chatRumor({
    required String senderPubkey,
    required String recipientPubkey,
    required String text,
    String? replyTo,
    int? createdAt,
  }) => Nip01Event(
    pubKey: senderPubkey,
    kind: kindChat,
    tags: [
      ['p', recipientPubkey],
      if (replyTo != null) ['e', replyTo, '', 'reply'],
    ],
    content: text,
    // Always explicit: ndk computes the id from the constructor argument, so
    // relying on its "now" default would yield an id that doesn't match.
    createdAt: createdAt ?? _now(),
  );

  /// Rumor → seal (signed by the sender) → gift wrap (signed by a one-time
  /// key, addressed to [recipientPubkey]). The result is the only thing that
  /// leaves the device.
  static Future<Nip01Event> wrap({
    required Identity sender,
    required String recipientPubkey,
    required Nip01Event rumor,
  }) async {
    final senderSigner = Bip340EventSigner(
      privateKey: sender.privateKey,
      publicKey: sender.publicKey,
    );
    final seal = await senderSigner.sign(
      Nip01Event(
        pubKey: sender.publicKey,
        kind: kindSeal,
        tags: const [],
        content: await _encrypt(
          senderSigner,
          _json(rumor, withSig: false),
          recipientPubkey,
        ),
        createdAt: _jittered(rumor.createdAt),
      ),
    );

    final ephemeralPriv = Bip340.generatePrivateKey().privateKey!;
    final ephemeralPub = Bip340.getPublicKey(ephemeralPriv);
    final ephemeral = Bip340EventSigner(
      privateKey: ephemeralPriv,
      publicKey: ephemeralPub,
    );
    return ephemeral.sign(
      Nip01Event(
        pubKey: ephemeralPub,
        kind: kindGiftWrap,
        tags: [
          ['p', recipientPubkey],
        ],
        content: await _encrypt(
          ephemeral,
          _json(seal, withSig: true),
          recipientPubkey,
        ),
        createdAt: _jittered(rumor.createdAt),
      ),
    );
  }

  /// Opens a gift wrap addressed to [me]. Throws [Nip17Exception] on anything
  /// malformed, forged or not for us — callers drop those silently.
  static Future<Nip01Event> unwrap({
    required Identity me,
    required Nip01Event giftWrap,
  }) async {
    if (giftWrap.kind != kindGiftWrap) throw const Nip17Exception('not a wrap');
    if (!await verifier.verify(giftWrap)) {
      throw const Nip17Exception('bad wrap signature');
    }

    final mine = Bip340EventSigner(
      privateKey: me.privateKey,
      publicKey: me.publicKey,
    );
    final seal = _parse(
      await _decrypt(mine, giftWrap.content, giftWrap.pubKey),
    );
    if (seal.kind != kindSeal) throw const Nip17Exception('not a seal');
    if (!await verifier.verify(seal)) {
      throw const Nip17Exception('bad seal signature');
    }

    final rumor = _parse(await _decrypt(mine, seal.content, seal.pubKey));
    // The seal signature proves who sent it; the rumor's pubkey is only a
    // claim. Without this check anyone could impersonate any contact.
    if (rumor.pubKey != seal.pubKey) {
      throw const Nip17Exception('rumor author does not match seal signer');
    }
    // References (reactions, replies, dedupe) use the rumor id: it must be
    // the real hash of its content.
    if (!Nip01Utils.isIdValid(rumor)) {
      throw const Nip17Exception('rumor id mismatch');
    }
    return rumor;
  }

  // Through the signer's NIP-44 methods: ndk marks its Nip44 class itself
  // as experimental API.
  static Future<String> _encrypt(
    Bip340EventSigner signer,
    String plaintext,
    String recipientPubkey,
  ) async {
    final out = await signer.encryptNip44(
      plaintext: plaintext,
      recipientPubKey: recipientPubkey,
    );
    if (out == null) throw const Nip17Exception('encryption failed');
    return out;
  }

  static Future<String> _decrypt(
    Bip340EventSigner signer,
    String payload,
    String senderPubkey,
  ) async {
    try {
      final out = await signer.decryptNip44(
        ciphertext: payload,
        senderPubKey: senderPubkey,
      );
      if (out != null) return out;
    } catch (_) {
      // Fall through: any failure means "not for us / tampered".
    }
    throw const Nip17Exception('decryption failed');
  }

  static String _json(Nip01Event e, {required bool withSig}) {
    final map = Nip01EventModel.fromEntity(e).toJson();
    if (!withSig) map.remove('sig');
    return jsonEncode(map);
  }

  static Nip01Event _parse(String json) {
    try {
      return Nip01EventModel.fromJson(jsonDecode(json) as Map);
    } catch (_) {
      throw const Nip17Exception('malformed event');
    }
  }
}

class Nip17Exception implements Exception {
  const Nip17Exception(this.reason);
  final String reason;

  @override
  String toString() => 'Nip17Exception: $reason';
}
