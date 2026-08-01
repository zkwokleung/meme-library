import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why an image was rejected.
enum ImageRejection {
  empty,
  tooLarge,
  unsupportedFormat,
  animated,
  corrupt,
  tooManyPixels,
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
  });

  /// Original encoded bytes, stored untouched.
  final Uint8List bytes;

  final String mimeType;

  /// Canonical extension without a dot: `png`, `jpg`, or `webp`.
  final String fileExtension;

  final int width;
  final int height;
  final bool hasAlpha;

  int get sizeBytes => bytes.length;
}

/// Validates that bytes are a static PNG, JPEG, or WebP within size limits.
///
/// Animated images (APNG, animated WebP, GIF) and any other format are
/// rejected. The original bytes are never re-encoded.
class ImageValidator {
  const ImageValidator({
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
    this.maxPixels = defaultMaxPixels,
  });

  static const defaultMaxFileSizeBytes = 25 * 1024 * 1024;
  static const defaultMaxPixels = 50 * 1000 * 1000;

  final int maxFileSizeBytes;
  final int maxPixels;

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
    };

    final decoded = decoder.decode(bytes);
    if (decoded == null) {
      throw const ImageValidationException(
        ImageRejection.corrupt,
        'Image data could not be decoded',
      );
    }
    if (decoded.width * decoded.height > maxPixels) {
      throw ImageValidationException(
        ImageRejection.tooManyPixels,
        'Image is ${decoded.width}x${decoded.height}; pixel limit is $maxPixels',
      );
    }

    return ValidatedImage(
      bytes: bytes,
      mimeType: switch (format) {
        _Format.png => 'image/png',
        _Format.jpeg => 'image/jpeg',
        _Format.webp => 'image/webp',
      },
      fileExtension: switch (format) {
        _Format.png => 'png',
        _Format.jpeg => 'jpg',
        _Format.webp => 'webp',
      },
      width: decoded.width,
      height: decoded.height,
      hasAlpha: decoded.numChannels == 4,
    );
  }

  _Format _sniffFormat(Uint8List bytes) {
    if (_isPng(bytes)) {
      if (_pngHasAnimationChunk(bytes)) {
        throw const ImageValidationException(
          ImageRejection.animated,
          'Animated PNG is not supported',
        );
      }
      return _Format.png;
    }
    if (_isJpeg(bytes)) return _Format.jpeg;
    if (_isWebP(bytes)) {
      if (_webPIsAnimated(bytes)) {
        throw const ImageValidationException(
          ImageRejection.animated,
          'Animated WebP is not supported',
        );
      }
      return _Format.webp;
    }
    throw const ImageValidationException(
      ImageRejection.unsupportedFormat,
      'Only static PNG, JPEG, and WebP images are supported',
    );
  }

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

  /// Walks PNG chunks looking for an `acTL` chunk before `IDAT`, which
  /// marks the file as APNG.
  static bool _pngHasAnimationChunk(Uint8List b) {
    var offset = 8;
    final view = ByteData.sublistView(b);
    while (offset + 8 <= b.length) {
      final length = view.getUint32(offset);
      final type = String.fromCharCodes(b.sublist(offset + 4, offset + 8));
      if (type == 'acTL') return true;
      if (type == 'IDAT' || type == 'IEND') return false;
      offset += 12 + length;
    }
    return false;
  }

  /// Checks the VP8X animation flag and ANIM chunks.
  static bool _webPIsAnimated(Uint8List b) {
    if (b.length < 21) return false;
    final fourCc = String.fromCharCodes(b.sublist(12, 16));
    if (fourCc == 'VP8X' && (b[20] & 0x02) != 0) return true;
    // Defensive scan for ANIM chunk in the first kilobyte.
    final limit = b.length < 1024 ? b.length - 4 : 1024;
    for (var i = 12; i < limit; i++) {
      if (b[i] == 0x41 &&
          b[i + 1] == 0x4E &&
          b[i + 2] == 0x49 &&
          b[i + 3] == 0x4D) {
        return true;
      }
    }
    return false;
  }
}

enum _Format { png, jpeg, webp }
