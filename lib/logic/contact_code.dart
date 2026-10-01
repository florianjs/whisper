import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart'
    show BytesUtils, QuickCrypto;
import 'package:ndk/ndk.dart' show Nip19;

import 'identity.dart';
import 'relays.dart';

/// What a QR code / pasted invite carries: who, and where to reach them.
class ContactCode {
  const ContactCode(this.pubkey, [this.relays = const []]);

  /// Hex pubkey.
  final String pubkey;

  /// Their inbox relays (`wss://` only). Lets a new contact write to them
  /// without looking anything up on a directory that could be blocked.
  final List<String> relays;
}

/// Invite to put in a QR code: `nostr:nprofile…` (NIP-19) with inbox relays.
String encodeContactCode(String pubkey, List<String> relays) =>
    'nostr:${Nip19.encodeNprofile(pubkey: pubkey, relays: relays.take(4).toList())}';

/// Accepts `nprofile`, `npub` or hex, with or without `nostr:`. Relay hints
/// that aren't valid `wss://` URLs are dropped (untrusted input).
ContactCode? parseContactCode(String input) {
  var s = input.trim();
  if (s.toLowerCase().startsWith('nostr:')) s = s.substring(6);
  if (s.toLowerCase().startsWith('nprofile1')) {
    try {
      final p = Nip19.decodeNprofile(s.toLowerCase());
      final pubkey = parsePubkey(p.pubkey);
      if (pubkey == null) return null;
      final relays = <String>{
        for (final r in p.relays ?? const <String>[]) ?normalizeRelayUrl(r),
      }.take(8).toList();
      return ContactCode(pubkey, relays);
    } catch (_) {
      return null;
    }
  }
  final pubkey = parsePubkey(s);
  return pubkey == null ? null : ContactCode(pubkey);
}

/// Safety number: 60 digits (12 groups of 5), identical on both phones,
/// derived from both public keys. Comparing it out of band (in person, on a
/// call) proves nobody swapped a key in between. Same idea as Signal's.
String safetyNumber(String pubkeyA, String pubkeyB) {
  final sorted = [pubkeyA, pubkeyB]..sort();
  var digest = Uint8List.fromList(
    BytesUtils.fromHexString(sorted[0]) + BytesUtils.fromHexString(sorted[1]),
  );
  // Iterated so brute-forcing a key that matches a given number is costly.
  for (var i = 0; i < 5200; i++) {
    digest = Uint8List.fromList(QuickCrypto.sha512Hash(digest));
  }
  final groups = <String>[];
  for (var g = 0; g < 12; g++) {
    // 5 bytes → integer mod 100000, like Signal's fingerprint chunks.
    var n = 0;
    for (var b = 0; b < 5; b++) {
      n = (n * 256 + digest[g * 5 + b]) % 100000;
    }
    groups.add(n.toString().padLeft(5, '0'));
  }
  return groups.join(' ');
}
