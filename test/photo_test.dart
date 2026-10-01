import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';
import 'package:whisper/logic/photo.dart';

/// A noisy 1200×900 photo-like JPEG with GPS coordinates and a camera model
/// in its EXIF, rotated 90° via the orientation tag.
Uint8List gpsTaggedPhoto() {
  final image = img.Image(width: 1200, height: 900);
  var seed = 7;
  for (final p in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    p
      ..r = (p.x * 255 ~/ 1200 + seed % 40) % 256
      ..g = (p.y * 255 ~/ 900 + seed % 60) % 256
      ..b = seed % 256;
  }
  image.exif.imageIfd['Model'] = img.IfdValueAscii('SpyPhone 9000');
  image.exif.imageIfd['Orientation'] = img.IfdValueShort(6); // 90° CW
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(48, 1);
  return img.encodeJpg(image, quality: 95);
}

void main() {
  test('fixture really carries GPS + model (sanity)', () {
    final decoded = img.decodeJpg(gpsTaggedPhoto())!;
    expect(decoded.exif.gpsIfd.isEmpty, isFalse);
    expect(decoded.exif.imageIfd['Model'].toString(), contains('SpyPhone'));
  });

  test('output is square, small, and has no EXIF at all', () {
    final input = gpsTaggedPhoto();
    final out = processProfilePhoto(input);
    expect(out.length, lessThanOrEqualTo(maxPhotoBytes));

    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, decoded.height);
    expect(decoded.width, lessThanOrEqualTo(256));
    expect(decoded.exif.isEmpty, isTrue);
    // Belt and braces: no trace in the raw bytes either.
    final raw = latin1.decode(out, allowInvalid: true);
    expect(raw, isNot(contains('SpyPhone')));
    expect(raw, isNot(contains('Exif')));
  });

  test('orientation is applied exactly once', () {
    // Landscape pixels tagged "rotate 90°" = the portrait photo the user saw.
    // The JPEG decoder already applies the tag and drops it, so the extra
    // bakeOrientation in processProfilePhoto must be a no-op here (no double
    // rotation); it only matters for formats that don't auto-orient.
    final decoded = img.decodeJpg(gpsTaggedPhoto())!;
    expect((decoded.width, decoded.height), (900, 1200));
    final baked = img.bakeOrientation(decoded);
    expect((baked.width, baked.height), (900, 1200));
  });

  test('rejects non-images', () {
    expect(
      () => processProfilePhoto(Uint8List.fromList(utf8.encode('hello'))),
      throwsFormatException,
    );
  });

  group('ProfileCard', () {
    test('round trip through a rumor', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final rumor = ProfileCard(
        version: 3,
        image: bytes,
        wantsYours: true,
      ).toRumor(sender: 'a' * 64, recipient: 'b' * 64);
      final card = ProfileCard.fromRumor(rumor)!;
      expect(card.version, 3);
      expect(card.image, bytes);
      expect(card.wantsYours, isTrue);
    });

    test('removal card has no image', () {
      final rumor = const ProfileCard(
        version: 4,
      ).toRumor(sender: 'a' * 64, recipient: 'b' * 64);
      expect(ProfileCard.fromRumor(rumor)!.image, isNull);
    });

    test('malformed or oversized cards are rejected', () {
      Nip01Event withContent(String c) => Nip01Event(
        pubKey: 'a' * 64,
        kind: ProfileCard.kind,
        tags: const [],
        content: c,
        createdAt: 1700000000,
      );
      expect(ProfileCard.fromRumor(withContent('not json')), isNull);
      expect(ProfileCard.fromRumor(withContent('{"v":"x"}')), isNull);
      expect(ProfileCard.fromRumor(withContent('{"v":-1}')), isNull);
      final huge = base64Encode(Uint8List(maxPhotoBytes + 1));
      expect(
        ProfileCard.fromRumor(withContent('{"v":1,"image":"$huge"}')),
        isNull,
      );
    });

    test('a max-size card still fits in a gift wrap', () async {
      final priv = Bip340.generatePrivateKey().privateKey!;
      final me = Identity(
        privateKey: priv,
        publicKey: Bip340.getPublicKey(priv),
      );
      final rumor = ProfileCard(
        version: 1,
        image: Uint8List(maxPhotoBytes),
      ).toRumor(sender: me.publicKey, recipient: me.publicKey);
      final wrap = await Nip17.wrap(
        sender: me,
        recipientPubkey: me.publicKey,
        rumor: rumor,
      );
      // Whole event as sent to relays: keep clear of 64 KB relay limits.
      expect(wrap.content.length, lessThan(48 * 1024));
      final back = await Nip17.unwrap(me: me, giftWrap: wrap);
      expect(ProfileCard.fromRumor(back)!.image!.length, maxPhotoBytes);
    });
  });
}
