import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deterministic PNG with a solid color; vary [seed] to vary the hash.
Uint8List pngBytes({int width = 8, int height = 8, int seed = 0}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(
    image,
    color: img.ColorRgba8(seed % 256, (seed * 7) % 256, (seed * 13) % 256, 255),
  );
  return img.encodePng(image);
}

Uint8List jpegBytes({int width = 8, int height = 8, int seed = 0}) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgb8(seed % 256, (seed * 7) % 256, (seed * 13) % 256),
  );
  return img.encodeJpg(image);
}

/// A well-known valid 1x1 lossy WebP file.
Uint8List webpBytes() => base64Decode(
  'UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=',
);

/// A WebP header with the VP8X animation flag set.
Uint8List animatedWebpBytes() {
  final b = Uint8List(64);
  b.setRange(0, 4, 'RIFF'.codeUnits);
  ByteData.sublistView(b).setUint32(4, 56, Endian.little);
  b.setRange(8, 12, 'WEBP'.codeUnits);
  b.setRange(12, 16, 'VP8X'.codeUnits);
  ByteData.sublistView(b).setUint32(16, 10, Endian.little);
  b[20] = 0x02; // animation flag
  return b;
}

/// A valid PNG with an `acTL` (APNG animation control) chunk inserted
/// before IDAT. The chunk CRC is bogus, but animation detection happens
/// before decoding.
Uint8List apngBytes() {
  final base = pngBytes();
  // IHDR is always the first chunk: 8 signature + 25 IHDR bytes.
  const insertAt = 8 + 25;
  final acTl = Uint8List(20);
  final view = ByteData.sublistView(acTl);
  view.setUint32(0, 8);
  acTl.setRange(4, 8, 'acTL'.codeUnits);
  view.setUint32(8, 1); // num_frames
  view.setUint32(12, 0); // num_plays
  view.setUint32(16, 0); // (unchecked) crc
  return Uint8List.fromList([
    ...base.sublist(0, insertAt),
    ...acTl,
    ...base.sublist(insertAt),
  ]);
}

Uint8List gifBytes() =>
    Uint8List.fromList([...'GIF89a'.codeUnits, ...List.filled(32, 0)]);
