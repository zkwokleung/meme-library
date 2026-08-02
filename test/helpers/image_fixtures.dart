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

/// A real animated GIF with [frames] distinct solid-color frames.
Uint8List animatedGifBytes({
  int frames = 4,
  int width = 16,
  int height = 16,
  int seed = 0,
}) {
  final encoder = img.GifEncoder();
  for (var i = 0; i < frames; i++) {
    final frame = img.Image(width: width, height: height);
    img.fill(
      frame,
      color: img.ColorRgb8(
        (40 * i + seed * 3) % 256,
        (90 + 30 * i + seed) % 256,
        (200 + 25 * i) % 256,
      ),
    );
    encoder.addFrame(frame, duration: 10);
  }
  return encoder.finish()!;
}

/// A real single-frame GIF.
Uint8List staticGifBytes({int width = 8, int height = 8, int seed = 0}) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgb8(seed % 256, (seed * 11) % 256, (seed * 29) % 256),
  );
  return img.encodeGif(image);
}

/// A real APNG: encodePng emits animation chunks for multi-frame input.
Uint8List animatedPngBytes({int frames = 3, int width = 8, int height = 8}) {
  img.Image? animation;
  for (var i = 0; i < frames; i++) {
    final frame = img.Image(width: width, height: height, numChannels: 4);
    img.fill(frame, color: img.ColorRgba8(60 * i, 255 - 60 * i, 80, 255));
    frame.frameDuration = 100;
    if (animation == null) {
      animation = frame;
    } else {
      animation.addFrame(frame);
    }
  }
  return img.encodePng(animation!);
}

/// Bytes with no recognizable image signature.
Uint8List unknownFormatBytes() => Uint8List.fromList(List.filled(64, 42));

/// A valid PNG with an `acTL` (APNG animation control) chunk inserted
/// before IDAT declaring a single frame. The chunk CRC is bogus, but
/// header parsing tolerates it; this pins the "acTL present but not
/// actually animated" edge case.
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

/// A GIF signature followed by garbage: sniffs as GIF, fails to decode.
Uint8List gifBytes() =>
    Uint8List.fromList([...'GIF89a'.codeUnits, ...List.filled(32, 0)]);
