import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/image_transfer.dart';
import 'package:whisper/logic/nip17.dart';
import 'package:whisper/logic/photo.dart';

import 'photo_test.dart' show gpsTaggedPhoto;

Uint8List randomBytes(int n, [int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

ImageHeader headerFor(Uint8List bytes, String fileId) => ImageHeader(
  fileId: fileId,
  sha256: ImageTransfer.sha256Hex(bytes),
  size: bytes.length,
  chunks: ImageTransfer.split(bytes).length,
  width: 800,
  height: 600,
);

const sender = 'aa';

void main() {
  group('anonymizeChatImage', () {
    test('strips GPS/camera model, applies rotation, caps size', () {
      final out = anonymizeChatImage(gpsTaggedPhoto());
      expect(out.bytes.length, lessThanOrEqualTo(maxChatImageBytes));
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.exif.isEmpty, isTrue);
      expect(String.fromCharCodes(out.bytes), isNot(contains('SpyPhone')));
      // Fixture is landscape + "rotate 90°": the user saw a portrait photo.
      expect(out.height, greaterThan(out.width));
      expect((decoded.width, decoded.height), (out.width, out.height));
    });

    test('keeps small images at their size', () {
      final small = img.encodeJpg(img.Image(width: 300, height: 200));
      final out = anonymizeChatImage(small);
      expect((out.width, out.height), (300, 200));
    });
  });

  group('Reassembler', () {
    test('header first, then chunks in any order', () {
      final bytes = randomBytes(40000);
      final id = ImageTransfer.newFileId(Random(1));
      final chunks = ImageTransfer.split(bytes);
      expect(chunks, hasLength(4));

      final r = Reassembler();
      expect(r.addHeader(sender, headerFor(bytes, id)), isNull);
      expect(r.addChunk(sender, ImageChunk(id, 2, chunks[2])), isNull);
      expect(r.addChunk(sender, ImageChunk(id, 0, chunks[0])), isNull);
      expect(r.progress(sender, id), (2, 4));
      expect(r.addChunk(sender, ImageChunk(id, 3, chunks[3])), isNull);
      expect(r.addChunk(sender, ImageChunk(id, 1, chunks[1])), bytes);
    });

    test('chunks before the header', () {
      final bytes = randomBytes(30000);
      final id = ImageTransfer.newFileId(Random(2));
      final r = Reassembler();
      final chunks = ImageTransfer.split(bytes);
      for (var i = 0; i < chunks.length; i++) {
        expect(r.addChunk(sender, ImageChunk(id, i, chunks[i])), isNull);
      }
      expect(r.addHeader(sender, headerFor(bytes, id)), bytes);
    });

    test('tampered chunk fails the hash and is dropped', () {
      final bytes = randomBytes(30000);
      final id = ImageTransfer.newFileId(Random(3));
      final r = Reassembler()..addHeader(sender, headerFor(bytes, id));
      final chunks = ImageTransfer.split(bytes);
      final bad = Uint8List.fromList(chunks[1])..[5] ^= 0xff;
      r.addChunk(sender, ImageChunk(id, 0, chunks[0]));
      r.addChunk(sender, ImageChunk(id, 1, bad));
      expect(r.addChunk(sender, ImageChunk(id, 2, chunks[2])), isNull);
      expect(r.progress(sender, id), isNull, reason: 'slot discarded');
    });

    test('another sender cannot complete or poison my file', () {
      final bytes = randomBytes(20000);
      final id = ImageTransfer.newFileId(Random(4));
      final r = Reassembler()..addHeader(sender, headerFor(bytes, id));
      final chunks = ImageTransfer.split(bytes);
      r.addChunk('mallory', ImageChunk(id, 0, randomBytes(chunks[0].length)));
      r.addChunk(sender, ImageChunk(id, 0, chunks[0]));
      expect(r.addChunk(sender, ImageChunk(id, 1, chunks[1])), bytes);
    });

    test('pending files are capped and expire', () {
      var now = DateTime(2026);
      final r = Reassembler(now: () => now);
      for (var i = 0; i < Reassembler.maxPendingFiles + 5; i++) {
        r.addChunk(
          sender,
          ImageChunk(ImageTransfer.newFileId(Random(i)), 0, randomBytes(10)),
        );
      }
      final bytes = randomBytes(20000);
      final id = ImageTransfer.newFileId(Random(99));
      r.addHeader(sender, headerFor(bytes, id));
      expect(r.progress(sender, id), (0, 2));
      now = now.add(Reassembler.maxAge + const Duration(minutes: 1));
      r.addChunk(
        sender,
        ImageChunk(ImageTransfer.newFileId(Random(7)), 0, randomBytes(10)),
      );
      expect(r.progress(sender, id), isNull);
    });
  });

  group('ImageHeader validation', () {
    ImageHeader? parse(Map<String, Object> patch) => ImageHeader.fromJson({
      ...headerFor(randomBytes(30000), 'ab' * 16).toJson(),
      ...patch,
    });

    test('accepts a well-formed header', () {
      expect(parse({}), isNotNull);
    });

    test('rejects lies and oversize', () {
      expect(parse({'f': 'nothex'}), isNull);
      expect(parse({'h': 'zz'}), isNull);
      expect(parse({'n': 99}), isNull, reason: 'n must match size');
      expect(
        parse({
          's': ImageTransfer.maxBytes + 1,
          // Consistent chunk count, so only the size cap can reject it.
          'n': ((ImageTransfer.maxBytes + 1) / ImageTransfer.chunkBytes).ceil(),
        }),
        isNull,
      );
      expect(parse({'w': 100000}), isNull);
    });
  });

  test('a full-size chunk still fits comfortably in a gift wrap', () async {
    final priv = Bip340.generatePrivateKey().privateKey!;
    final me = Identity(privateKey: priv, publicKey: Bip340.getPublicKey(priv));
    final rumor = ImageTransfer.chunkRumor(
      sender: me.publicKey,
      recipient: me.publicKey,
      fileId: ImageTransfer.newFileId(),
      index: 0,
      data: randomBytes(ImageTransfer.chunkBytes),
    );
    final wrap = await Nip17.wrap(
      sender: me,
      recipientPubkey: me.publicKey,
      rumor: rumor,
    );
    expect(wrap.content.length, lessThan(48 * 1024));
    final back = await Nip17.unwrap(me: me, giftWrap: wrap);
    expect(ImageChunk.fromRumor(back)!.data.length, ImageTransfer.chunkBytes);
  });
}
