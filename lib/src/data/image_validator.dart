import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why an image was rejected.
enum ImageRejection {
  empty,
  tooLarge,
  unsupportedFormat,
  corrupt,
  tooManyPixels,

  /// A HEIC/HEIF image: no bundled decoder can read it, but the platform
  /// can transcode it to JPEG first. Distinct from [unsupportedFormat] so
  /// the message can say so.
  needsConversion,
}

class ImageValidationException implements Exception {
  const ImageValidationException(this.rejection, this.message);

  final ImageRejection rejection;
  final String message;

  @override
  String toString() => 'ImageValidationException($rejection): $message';
}

/// A decoded, accepted image ready for storage.
class ValidatedImage {
  const ValidatedImage({
    required this.bytes,
    required this.mimeType,
    required this.fileExtension,
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.frameCount,
  });

  /// Original encoded bytes, stored untouched.
  final Uint8List bytes;

  final String mimeType;

  /// Canonical extension without a dot: `png`, `jpg`, `webp`, or `gif`.
  final String fileExtension;

  /// Canvas dimensions as the image is displayed: EXIF orientation is
  /// already applied, so these match the thumbnail and what Flutter
  /// renders. For animations these are the header's canvas dimensions (an
  /// animation frame can be a sub-rect of the canvas).
  final int width;
  final int height;

  final bool hasAlpha;
  final int frameCount;

  bool get isAnimated => frameCount > 1;

  int get sizeBytes => bytes.length;
}

/// Validates that bytes are a PNG, JPEG, WebP, or GIF within size limits.
///
/// Animated images (GIF, APNG, animated WebP) are accepted, bounded by
/// [maxFrames] and [maxTotalFramePixels]. The original bytes are never
/// re-encoded, and validation never rasterizes more than one frame.
class ImageValidator {
  const ImageValidator({
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
    this.maxPixels = defaultMaxPixels,
    this.maxTotalFramePixels = defaultMaxTotalFramePixels,
    this.maxFrames = defaultMaxFrames,
  });

  static const defaultMaxFileSizeBytes = 25 * 1024 * 1024;
  static const defaultMaxPixels = 50 * 1000 * 1000;

  /// Frames x canvas pixels: caps the memory of a full animation decode
  /// at the same level as the existing static worst case.
  static const defaultMaxTotalFramePixels = 50 * 1000 * 1000;

  /// Guards degenerate files (a tiny canvas can otherwise declare
  /// millions of frames whose object overhead alone would exhaust memory).
  static const defaultMaxFrames = 1000;

  final int maxFileSizeBytes;
  final int maxPixels;
  final int maxTotalFramePixels;
  final int maxFrames;

  ValidatedImage validate(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const ImageValidationException(ImageRejection.empty, 'No data');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw ImageValidationException(
        ImageRejection.tooLarge,
        'File is ${bytes.length} bytes; limit is $maxFileSizeBytes',
      );
    }

    final format = _sniffFormat(bytes);
    final decoder = switch (format) {
      _Format.png => img.PngDecoder(),
      _Format.jpeg => img.JpegDecoder(),
      _Format.webp => img.WebPDecoder(),
      _Format.gif => img.GifDecoder(),
    };

    // Check declared dimensions and frame counts from the header BEFORE
    // rasterizing: a tiny compressed file can declare a huge canvas or
    // frame list (decompression bomb) and the allocation itself would
    // take the app down.
    final img.DecodeInfo info;
    final img.Image? firstFrame;
    try {
      final parsed = decoder.startDecode(bytes);
      if (parsed == null) {
        throw const ImageValidationException(
          ImageRejection.corrupt,
          'Image data could not be decoded',
        );
      }
      info = parsed;
      if (info.width * info.height > maxPixels) {
        throw ImageValidationException(
          ImageRejection.tooManyPixels,
          'Image is ${info.width}x${info.height}; pixel limit is $maxPixels',
        );
      }
      final frameCount = info.numFrames < 1 ? 1 : info.numFrames;
      if (frameCount > maxFrames ||
          frameCount * info.width * info.height > maxTotalFramePixels) {
        throw ImageValidationException(
          ImageRejection.tooManyPixels,
          'Animation of $frameCount frames at ${info.width}x${info.height} '
          'exceeds the pixel limit',
        );
      }
      // Integrity check on a single frame only; the full animation is
      // never rasterized during validation.
      firstFrame = decoder.decodeFrame(0);
    } on ImageValidationException {
      rethrow;
    } catch (_) {
      // The decoder throws (rather than returning null) on some
      // malformed inputs.
      throw const ImageValidationException(
        ImageRejection.corrupt,
        'Image data could not be decoded',
      );
    }
    if (firstFrame == null) {
      throw const ImageValidationException(
        ImageRejection.corrupt,
        'Image data could not be decoded',
      );
    }

    // The JPEG decoder bakes EXIF orientation into the frame it returns,
    // swapping width and height for orientations 5-8; the SOF header does
    // not. Trust the decoded frame when it is a transpose of the header so
    // the stored dimensions match the thumbnail and what Flutter renders.
    // Animated canvases keep the header dimensions: an animation frame can
    // be a sub-rect of the canvas.
    final frames = info.numFrames < 1 ? 1 : info.numFrames;
    final transposed =
        frames == 1 &&
        info.width != info.height &&
        firstFrame.width == info.height &&
        firstFrame.height == info.width;

    return ValidatedImage(
      bytes: bytes,
      mimeType: switch (format) {
        _Format.png => 'image/png',
        _Format.jpeg => 'image/jpeg',
        _Format.webp => 'image/webp',
        _Format.gif => 'image/gif',
      },
      fileExtension: switch (format) {
        _Format.png => 'png',
        _Format.jpeg => 'jpg',
        _Format.webp => 'webp',
        _Format.gif => 'gif',
      },
      width: transposed ? info.height : info.width,
      height: transposed ? info.width : info.height,
      // 4 = RGBA; 2 = grayscale + alpha (PNG color type 4); a 4-channel
      // palette means an indexed image with a transparent entry (GIF,
      // indexed PNG).
      hasAlpha:
          firstFrame.numChannels == 4 ||
          firstFrame.numChannels == 2 ||
          (firstFrame.palette?.numChannels == 4),
      frameCount: info.numFrames < 1 ? 1 : info.numFrames,
    );
  }

  _Format _sniffFormat(Uint8List bytes) {
    if (_isPng(bytes)) return _Format.png;
    if (_isJpeg(bytes)) return _Format.jpeg;
    if (_isWebP(bytes)) return _Format.webp;
    if (_isGif(bytes)) return _Format.gif;
    // After the four supported sniffs, and unambiguous against them: an
    // ISO-BMFF file starts with a box length, not a fixed signature.
    if (isHeif(bytes)) {
      throw const ImageValidationException(
        ImageRejection.needsConversion,
        'HEIC/HEIF images must be converted to JPEG before import',
      );
    }
    throw const ImageValidationException(
      ImageRejection.unsupportedFormat,
      'Only PNG, JPEG, WebP, and GIF images are supported',
    );
  }

  /// HEIF-family brands. `avif`/`avis` are AV1-in-HEIF: equally
  /// undecodable here, and handled by the same native transcoder.
  static const _heifBrands = <String>{
    'heic', 'heix', 'heim', 'heis', // HEVC still image
    'hevc', 'hevx', 'hevm', 'hevs', // HEVC image sequence
    'mif1', 'msf1', 'miaf', // generic HEIF / MIAF
    'avif', 'avis', // AV1 in HEIF
  };

  /// Whether [b] is an ISO-BMFF `ftyp` box carrying a HEIF-family brand.
  ///
  /// Both the major brand and the compatible-brand list are checked:
  /// iPhones write major `heic`, while some Android devices write major
  /// `mif1` with `heic` only in the compatible list.
  ///
  /// Public so the gallery import path can route a file to the native
  /// transcoder from its header alone, without reading the whole file or
  /// catching an exception.
  static bool isHeif(Uint8List b) {
    if (b.length < 16) return false;
    // 'ftyp' at offset 4.
    if (b[4] != 0x66 || b[5] != 0x74 || b[6] != 0x79 || b[7] != 0x70) {
      return false;
    }
    if (_heifBrands.contains(_brandAt(b, 8))) return true;

    // Compatible brands run from offset 16 to the end of the ftyp box.
    // The declared size comes from the file, so bound the scan by the
    // buffer length and by a sane ceiling as well.
    final declared = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    var end = b.length;
    if (declared >= 16 && declared < end) end = declared;
    if (end > 128) end = 128;
    for (var i = 16; i + 4 <= end; i += 4) {
      if (_heifBrands.contains(_brandAt(b, i))) return true;
    }
    return false;
  }

  static String _brandAt(Uint8List b, int offset) =>
      String.fromCharCodes(b, offset, offset + 4);

  static bool _isPng(Uint8List b) =>
      b.length > 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  static bool _isJpeg(Uint8List b) =>
      b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static bool _isWebP(Uint8List b) =>
      b.length > 12 &&
      b[0] == 0x52 && // RIFF
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 && // WEBP
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50;

  /// `GIF87a` or `GIF89a`.
  static bool _isGif(Uint8List b) =>
      b.length > 6 &&
      b[0] == 0x47 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x38 &&
      (b[4] == 0x37 || b[4] == 0x39) &&
      b[5] == 0x61;
}

enum _Format { png, jpeg, webp, gif }
