import 'dart:typed_data';

import 'package:image/image.dart' as img;

const stickerDimension = 512;
const trayIconDimension = 96;

/// Why a meme cannot become a static sticker.
enum StickerImageError { animated, undecodable }

/// Carries only an enum so it survives an isolate boundary intact.
class StickerImageException implements Exception {
  const StickerImageException(this.error);

  final StickerImageError error;

  @override
  String toString() => 'StickerImageException(${error.name})';
}

/// Pixel data for one sticker at WhatsApp's required sizes: a raw
/// 512x512 RGBA buffer ready for a native WebP encoder, plus the 96x96
/// tray icon already encoded as PNG.
class StickerSource {
  const StickerSource({required this.rgba, required this.trayPng});

  final Uint8List rgba;
  final Uint8List trayPng;
}

/// Prepares one meme for sticker export: decode, bake EXIF orientation,
/// scale the longest edge to exactly [stickerDimension], and center on a
/// transparent square canvas.
///
/// Top-level, pure, and free of `dart:io` so it can run on a background
/// isolate. Throws [StickerImageException] for animated or undecodable
/// sources; animated memes are excluded from packs rather than silently
/// flattened to their first frame.
StickerSource stickerSourceSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const StickerImageException(StickerImageError.undecodable);
  }
  if (decoded.numFrames > 1) {
    throw const StickerImageException(StickerImageError.animated);
  }

  // Same guard as the thumbnail path: some decoders (WebP) report EXIF
  // orientation without applying it.
  final upright =
      decoded.exif.imageIfd.hasOrientation &&
          decoded.exif.imageIfd.orientation != 1
      ? img.bakeOrientation(decoded)
      : decoded;

  final scaleToWidth = upright.width >= upright.height;
  final resized = img.copyResize(
    upright,
    width: scaleToWidth ? stickerDimension : null,
    height: scaleToWidth ? null : stickerDimension,
    interpolation:
        upright.width > stickerDimension || upright.height > stickerDimension
        ? img.Interpolation.average
        : img.Interpolation.linear,
  );

  final canvas = img.Image(
    width: stickerDimension,
    height: stickerDimension,
    numChannels: 4,
  );
  img.compositeImage(
    canvas,
    resized,
    dstX: (stickerDimension - resized.width) ~/ 2,
    dstY: (stickerDimension - resized.height) ~/ 2,
  );

  final tray = img.copyResize(
    canvas,
    width: trayIconDimension,
    height: trayIconDimension,
    interpolation: img.Interpolation.average,
  );

  return StickerSource(
    rgba: canvas.getBytes(order: img.ChannelOrder.rgba),
    trayPng: img.encodePng(tray),
  );
}
