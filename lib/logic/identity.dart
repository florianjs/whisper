import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:ndk/ndk.dart' show Nip19;
import 'package:ndk/shared/nips/nip01/bip340.dart';

/// NIP-06 derivation path for the account's main Nostr key.
const nip06Path = "m/44'/1237'/0'/0/0";

/// A Nostr identity derived from a BIP39 mnemonic. Hex keys are 32 bytes;
/// [publicKey] is the BIP340 x-only key.
class Identity {
  const Identity({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;

  String get npub => Nip19.encodePubKey(publicKey);
  String get nsec => Nip19.encodePrivateKey(privateKey);
  String get username => usernameFor(publicKey);
}

/// Fresh 24-word English mnemonic from a CSPRNG (256 bits of entropy).
String generateMnemonic() =>
    Bip39MnemonicGenerator().fromWordsNumber(Bip39WordsNum.wordsNum24).toStr();

/// Lowercases and collapses whitespace so pasted phrases validate.
String normalizeMnemonic(String input) =>
    input.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

/// Checks word list membership and the BIP39 checksum.
bool isValidMnemonic(String mnemonic) =>
    Bip39MnemonicValidator().isValid(normalizeMnemonic(mnemonic));

/// Derives the account key per NIP-06. Throws [ArgumentError] on an invalid
/// mnemonic so a bad restore never silently yields a different identity.
Identity deriveIdentity(String mnemonic) {
  final normalized = normalizeMnemonic(mnemonic);
  if (!Bip39MnemonicValidator().isValid(normalized)) {
    throw ArgumentError('invalid mnemonic');
  }
  final seed = Bip39SeedGenerator(Mnemonic.fromString(normalized)).generate();
  final node = Bip32Slip10Secp256k1.fromSeed(seed).derivePath(nip06Path);
  final privateKey = BytesUtils.toHexString(node.privateKey.raw);
  return Identity(
    privateKey: privateKey,
    publicKey: Bip340.getPublicKey(privateKey),
  );
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// Hex pubkey from what a user pastes: `npub1…` (optionally prefixed with
/// `nostr:`) or raw hex. Null if it isn't a valid public key.
String? parsePubkey(String input) {
  var s = input.trim().toLowerCase();
  if (s.startsWith('nostr:')) s = s.substring(6);
  String hex;
  if (s.startsWith('npub1')) {
    try {
      hex = Nip19.decode(s);
    } catch (_) {
      return null;
    }
  } else {
    hex = s;
  }
  if (!_hex64.hasMatch(hex)) return null;
  // Must be an x coordinate on secp256k1, or messages to it can't be
  // encrypted; the NIP-19 checksum alone doesn't guarantee that.
  try {
    Secp256k1PublicKey.fromBytes(BytesUtils.fromHexString('02$hex'));
  } catch (_) {
    return null;
  }
  return hex;
}

/// Deterministic, human-friendly handle from a hex public key, e.g.
/// `swift-otter-4821`. Display only — two keys can collide, so the npub
/// stays the real identifier. English words: persisted data stays locale-free.
String usernameFor(String publicKeyHex) {
  final h = QuickCrypto.sha256Hash(BytesUtils.fromHexString(publicKeyHex));
  final adjective = _adjectives[h[0] % _adjectives.length];
  final animal = _animals[h[1] % _animals.length];
  final number = ((h[2] << 8 | h[3]) % 10000).toString().padLeft(4, '0');
  return '$adjective-$animal-$number';
}

// 64 entries each so a single hash byte maps without modulo bias.
// dart format off
const _adjectives = [
  'amber', 'ancient', 'arctic', 'azure', 'bold', 'brave', 'bright', 'calm',
  'clever', 'cosmic', 'crimson', 'curious', 'dapper', 'daring', 'dusky', 'eager',
  'electric', 'emerald', 'fierce', 'frosty', 'gentle', 'gilded', 'golden', 'hidden',
  'hollow', 'humble', 'icy', 'indigo', 'jolly', 'keen', 'lively', 'lucky',
  'lunar', 'mellow', 'misty', 'mystic', 'nimble', 'noble', 'odd', 'pale',
  'plucky', 'quiet', 'quick', 'rapid', 'rustic', 'scarlet', 'shadow', 'silent',
  'silver', 'sly', 'solar', 'steady', 'stormy', 'swift', 'tidal', 'tiny',
  'velvet', 'vivid', 'wandering', 'wild', 'wise', 'witty', 'young', 'zesty',
];

const _animals = [
  'albatross', 'badger', 'bat', 'bear', 'beaver', 'bison', 'bobcat', 'crane',
  'cobra', 'coyote', 'crow', 'deer', 'dolphin', 'dove', 'eagle', 'eel',
  'falcon', 'ferret', 'finch', 'fox', 'gecko', 'gull', 'hare', 'hawk',
  'heron', 'ibex', 'jackal', 'jaguar', 'koala', 'lark', 'lemur', 'lion',
  'lynx', 'magpie', 'marten', 'mink', 'moose', 'moth', 'newt', 'ocelot',
  'octopus', 'orca', 'otter', 'owl', 'panda', 'panther', 'puffin', 'raven',
  'seal', 'shark', 'sparrow', 'squid', 'stoat', 'swan', 'tiger', 'toad',
  'viper', 'walrus', 'weasel', 'whale', 'wolf', 'wombat', 'wren', 'yak',
];
// dart format on
