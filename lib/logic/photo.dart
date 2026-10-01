import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:ndk/ndk.dart' show Nip01Event;

import 'nickname.dart';

/// Largest JPEG we send. Base64 + two NIP-44 layers inflate it ~3.4×
/// (measured on real relays: a 16 KB photo became a 54.7 KB event), so 12 KB
/// keeps the gift wrap near 41 KB: under NIP-44's 64 KB plaintext cap and
/// common 64 KB relay event limits, with margin.
const maxPhotoBytes = 12 * 1024;

class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException();
}

/// Square, small, re-encoded JPEG with **no metadata**: phone photos carry
/// EXIF (GPS position, device model, capture time) that must never leave the
/// device. Heavy: call through `compute`.
Uint8List processProfilePhoto(Uint8List input) {
  final decoded = _decode(input);
  // Apply the EXIF rotation into the pixels first, or stripping the tag
  // would leave portrait photos sideways. (The JPEG decoder already does it
  // and drops the tag, making this a no-op there; other formats need it.)
  final upright = img.bakeOrientation(decoded);

  for (final size in const [256, 192, 128]) {
    final square = img.copyResizeCropSquare(
      upright,
      size: size,
      interpolation: img.Interpolation.average,
    )..exif = img.ExifData();
    for (final quality in const [82, 72, 62, 52, 42]) {
      final jpg = img.encodeJpg(square, quality: quality);
      if (jpg.length <= maxPhotoBytes) return jpg;
    }
  }
  throw const PhotoTooLargeException();
}

/// Largest image sent in a chat (split into chunks for transport).
const maxChatImageBytes = 250 * 1024;

/// Chat photo, anonymized: EXIF rotation applied, then re-encoded without any
/// metadata (GPS, device, time, thumbnails), longest side ≤ 1280 px. Downscaling
/// also weakens — but cannot erase — sensor-noise fingerprinting. Heavy: call
/// through `compute`. Returns JPEG bytes and their dimensions.
({Uint8List bytes, int width, int height}) anonymizeChatImage(Uint8List input) {
  final upright = img.bakeOrientation(_decode(input));
  for (final side in const [1280, 1024, 800]) {
    final longest = upright.width > upright.height
        ? upright.width
        : upright.height;
    final scaled = longest <= side
        ? img.Image.from(upright)
        : img.copyResize(
            upright,
            width: upright.width >= upright.height ? side : null,
            height: upright.height > upright.width ? side : null,
            interpolation: img.Interpolation.average,
          );
    scaled.exif = img.ExifData();
    for (final quality in const [80, 70, 60, 50]) {
      final jpg = img.encodeJpg(scaled, quality: quality);
      if (jpg.length <= maxChatImageBytes) {
        return (bytes: jpg, width: scaled.width, height: scaled.height);
      }
    }
  }
  throw const PhotoTooLargeException();
}

/// Decoders throw RangeError & co. on garbage; normalize to FormatException.
img.Image _decode(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) throw const FormatException('not an image');
  return decoded;
}

/// Private profile data sent inside a NIP-17 gift wrap to accepted contacts
/// only — never as public kind-0 metadata, which would bind a face to the
/// pubkey for anyone to see.
class ProfileCard {
  const ProfileCard({
    required this.version,
    this.image,
    this.name,
    this.wantsYours = false,
  });

  /// Monotonic; receivers ignore anything older than what they hold.
  final int version;

  /// JPEG bytes, or null when the photo was removed.
  final Uint8List? image;

  /// Chosen nickname ([sanitizeNickname]d), or null for none. Older cards
  /// have no name: they read as "no nickname".
  final String? name;

  /// Asks the receiver to send their own card back (used when accepting a
  /// contact whose card we never received).
  final bool wantsYours;

  /// Rumor kind for profile cards. Never published unwrapped, so it only has
  /// to be distinct from the chat kinds.
  static const kind = 14444;

  Nip01Event toRumor({required String sender, required String recipient}) =>
      Nip01Event(
        pubKey: sender,
        kind: kind,
        tags: [
          ['p', recipient],
        ],
        content: jsonEncode({
          'v': version,
          'image': image == null ? null : base64Encode(image!),
          if (name != null) 'name': name,
          if (wantsYours) 'want': true,
        }),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

  /// Null for anything malformed or oversized (it comes from the network).
  static ProfileCard? fromRumor(Nip01Event rumor) {
    if (rumor.kind != kind) return null;
    try {
      final json = jsonDecode(rumor.content) as Map<String, dynamic>;
      final version = json['v'];
      if (version is! int || version < 0) return null;
      final b64 = json['image'];
      Uint8List? image;
      if (b64 is String) {
        image = base64Decode(b64);
        if (image.length > maxPhotoBytes) return null;
      } else if (b64 != null) {
        return null;
      }
      final name = json['name'];
      return ProfileCard(
        version: version,
        image: image,
        // A bad name only loses the name, not the photo.
        name: name is String ? sanitizeNickname(name) : null,
        wantsYours: json['want'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
