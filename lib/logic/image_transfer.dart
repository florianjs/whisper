import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart' show QuickCrypto;
import 'package:ndk/ndk.dart' show Nip01Event;

import 'photo.dart';

/// Chat images over plain NIP-17 gift wraps: one header rumor (it *is* the
/// message: its id is the message id) plus N chunk rumors. No file server —
/// only the relays already in use, so nothing extra to block or to log.
class ImageTransfer {
  ImageTransfer._();

  static const kindHeader = 14446;
  static const kindChunk = 14445;

  /// Raw bytes per chunk. Base64 + two padded NIP-44 layers bring a 12 KB
  /// chunk to a ~40 KB event, clear of 64 KB relay limits.
  static const chunkBytes = 12 * 1024;

  /// Hard caps for what a peer can make us buffer.
  static const maxChunks = 24;
  static const maxBytes = maxChatImageBytes;

  static String newFileId([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String sha256Hex(Uint8List bytes) => QuickCrypto.sha256Hash(
    bytes,
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<Uint8List> split(Uint8List bytes) => [
    for (var i = 0; i < bytes.length; i += chunkBytes)
      Uint8List.sublistView(bytes, i, min(i + chunkBytes, bytes.length)),
  ];

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static Nip01Event headerRumor({
    required String sender,
    required String recipient,
    required ImageHeader header,
    int? createdAt,
  }) => Nip01Event(
    pubKey: sender,
    kind: kindHeader,
    tags: [
      ['p', recipient],
    ],
    content: jsonEncode(header.toJson()),
    createdAt: createdAt ?? _now(),
  );

  static Nip01Event chunkRumor({
    required String sender,
    required String recipient,
    required String fileId,
    required int index,
    required Uint8List data,
  }) => Nip01Event(
    pubKey: sender,
    kind: kindChunk,
    tags: [
      ['p', recipient],
    ],
    content: jsonEncode({'f': fileId, 'i': index, 'd': base64Encode(data)}),
    createdAt: _now(),
  );
}

class ImageHeader {
  const ImageHeader({
    required this.fileId,
    required this.sha256,
    required this.size,
    required this.chunks,
    required this.width,
    required this.height,
  });

  final String fileId;
  final String sha256;
  final int size;
  final int chunks;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'f': fileId,
    'h': sha256,
    's': size,
    'n': chunks,
    'w': width,
    'hh': height,
  };

  static final _hex32 = RegExp(r'^[0-9a-f]{32}$');
  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Null for anything malformed or beyond the caps (it comes from the net).
  static ImageHeader? fromJson(Object? json) {
    if (json is! Map) return null;
    final f = json['f'], h = json['h'], s = json['s'], n = json['n'];
    final w = json['w'], hh = json['hh'];
    if (f is! String || !_hex32.hasMatch(f)) return null;
    if (h is! String || !_hex64.hasMatch(h)) return null;
    if (s is! int || s <= 0 || s > ImageTransfer.maxBytes) return null;
    if (n is! int || n != (s / ImageTransfer.chunkBytes).ceil()) return null;
    if (n > ImageTransfer.maxChunks) return null;
    if (w is! int || hh is! int || w <= 0 || hh <= 0) return null;
    if (w > 4096 || hh > 4096) return null;
    return ImageHeader(
      fileId: f,
      sha256: h,
      size: s,
      chunks: n,
      width: w,
      height: hh,
    );
  }

  static ImageHeader? fromRumor(Nip01Event rumor) {
    if (rumor.kind != ImageTransfer.kindHeader) return null;
    try {
      return fromJson(jsonDecode(rumor.content));
    } catch (_) {
      return null;
    }
  }
}

class ImageChunk {
  const ImageChunk(this.fileId, this.index, this.data);
  final String fileId;
  final int index;
  final Uint8List data;

  static ImageChunk? fromRumor(Nip01Event rumor) {
    if (rumor.kind != ImageTransfer.kindChunk) return null;
    try {
      final json = jsonDecode(rumor.content) as Map;
      final f = json['f'], i = json['i'], d = json['d'];
      if (f is! String || i is! int || d is! String || i < 0) return null;
      final data = base64Decode(d);
      if (data.isEmpty || data.length > ImageTransfer.chunkBytes) return null;
      return ImageChunk(f, i, data);
    } catch (_) {
      return null;
    }
  }
}

/// Collects chunks until an image is complete. Chunks may arrive before
/// their header (relays don't preserve order). Everything a peer sends is
/// bounded: chunk count, size, pending files, age.
class Reassembler {
  Reassembler({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maxPendingFiles = 16;
  static const maxAge = Duration(minutes: 15);

  final DateTime Function() _now;
  final Map<String, _Pending> _pending = {};

  /// (have, total) for a file with a known header, else null.
  (int, int)? progress(String sender, String fileId) {
    final p = _pending['$sender/$fileId'];
    final h = p?.header;
    if (p == null || h == null) return null;
    return (p.chunks.length, h.chunks);
  }

  /// Returns the verified image bytes once [header] + all chunks are in.
  Uint8List? addHeader(String sender, ImageHeader header) {
    final p = _slot(sender, header.fileId);
    if (p == null) return null;
    p.header ??= header;
    return _tryComplete(sender, header.fileId, p);
  }

  Uint8List? addChunk(String sender, ImageChunk chunk) {
    final p = _slot(sender, chunk.fileId);
    if (p == null || chunk.index >= ImageTransfer.maxChunks) return null;
    p.chunks[chunk.index] = chunk.data;
    return _tryComplete(sender, chunk.fileId, p);
  }

  _Pending? _slot(String sender, String fileId) {
    _expire();
    final key = '$sender/$fileId';
    final existing = _pending[key];
    if (existing != null) return existing;
    if (_pending.length >= maxPendingFiles) {
      _pending.remove(_pending.keys.first);
    }
    return _pending[key] = _Pending(_now());
  }

  Uint8List? _tryComplete(String sender, String fileId, _Pending p) {
    final h = p.header;
    if (h == null) return null;
    // Chunks beyond what the header announced are junk.
    p.chunks.removeWhere((i, _) => i >= h.chunks);
    if (p.chunks.length < h.chunks) return null;
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < h.chunks; i++) {
      out.add(p.chunks[i]!);
    }
    final bytes = out.takeBytes();
    _pending.remove('$sender/$fileId');
    if (bytes.length != h.size || ImageTransfer.sha256Hex(bytes) != h.sha256) {
      return null; // Corrupted or forged: drop.
    }
    return bytes;
  }

  void _expire() {
    final cutoff = _now().subtract(maxAge);
    _pending.removeWhere((_, p) => p.createdAt.isBefore(cutoff));
  }

  void clear() => _pending.clear();
}

class _Pending {
  _Pending(this.createdAt);
  final DateTime createdAt;
  ImageHeader? header;
  final Map<int, Uint8List> chunks = {};
}
