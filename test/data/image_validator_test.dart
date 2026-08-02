import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meme_library/src/data/image_validator.dart';

import '../helpers/image_fixtures.dart';

void main() {
  const validator = ImageValidator();

  Matcher rejects(ImageRejection rejection) => throwsA(
    isA<ImageValidationException>().having(
      (e) => e.rejection,
      'rejection',
      rejection,
    ),
  );

  test('accepts static PNG and reports metadata', () {
    final result = validator.validate(pngBytes(width: 12, height: 5));
    expect(result.mimeType, 'image/png');
    expect(result.fileExtension, 'png');
    expect(result.width, 12);
    expect(result.height, 5);
    expect(result.hasAlpha, isTrue);
  });

  test('accepts JPEG', () {
    final result = validator.validate(jpegBytes());
    expect(result.mimeType, 'image/jpeg');
    expect(result.fileExtension, 'jpg');
    expect(result.hasAlpha, isFalse);
  });

  test('accepts static WebP', () {
    final result = validator.validate(webpBytes());
    expect(result.mimeType, 'image/webp');
    expect(result.width, 1);
    expect(result.height, 1);
  });

  test('rejects empty input', () {
    expect(
      () => validator.validate(Uint8List(0)),
      rejects(ImageRejection.empty),
    );
  });

  test('rejects oversized files without decoding', () {
    const small = ImageValidator(maxFileSizeBytes: 16);
    expect(() => small.validate(pngBytes()), rejects(ImageRejection.tooLarge));
  });

  test('accepts an animated GIF and reports frame metadata', () {
    final result = validator.validate(
      animatedGifBytes(frames: 4, width: 16, height: 12),
    );
    expect(result.mimeType, 'image/gif');
    expect(result.fileExtension, 'gif');
    expect(result.isAnimated, isTrue);
    expect(result.frameCount, 4);
    expect(result.width, 16);
    expect(result.height, 12);
  });

  test('accepts a static GIF', () {
    final result = validator.validate(staticGifBytes());
    expect(result.mimeType, 'image/gif');
    expect(result.isAnimated, isFalse);
    expect(result.frameCount, 1);
  });

  test('accepts an APNG', () {
    final result = validator.validate(animatedPngBytes(frames: 3));
    expect(result.mimeType, 'image/png');
    expect(result.isAnimated, isTrue);
    expect(result.frameCount, 3);
  });

  test('acTL chunk with a single declared frame stays static', () {
    final result = validator.validate(apngBytes());
    expect(result.isAnimated, isFalse);
  });

  test('rejects unknown formats', () {
    expect(
      () => validator.validate(unknownFormatBytes()),
      rejects(ImageRejection.unsupportedFormat),
    );
  });

  test('garbage with a GIF signature fails as corrupt', () {
    expect(
      () => validator.validate(gifBytes()),
      rejects(ImageRejection.corrupt),
    );
  });

  test('animated WebP header reaches the decode stage', () {
    // The fixture is a hand-built header, not a decodable file; reaching
    // `corrupt` (instead of unsupported/animated) proves the accept
    // branch is taken.
    expect(
      () => validator.validate(animatedWebpBytes()),
      rejects(ImageRejection.corrupt),
    );
  });

  test('rejects animations above the total-frame-pixel limit', () {
    const tiny = ImageValidator(maxTotalFramePixels: 500);
    expect(
      () => tiny.validate(animatedGifBytes(frames: 4, width: 16, height: 16)),
      rejects(ImageRejection.tooManyPixels),
    );
  });

  test('rejects animations above the frame-count limit', () {
    const tiny = ImageValidator(maxFrames: 2);
    expect(
      () => tiny.validate(animatedGifBytes(frames: 4)),
      rejects(ImageRejection.tooManyPixels),
    );
  });

  test('rejects corrupt data with a valid signature', () {
    final corrupt = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      ...List.filled(64, 7),
    ]);
    expect(() => validator.validate(corrupt), rejects(ImageRejection.corrupt));
  });

  test('rejects images above the pixel limit', () {
    const tiny = ImageValidator(maxPixels: 4);
    expect(
      () => tiny.validate(pngBytes(width: 4, height: 4)),
      rejects(ImageRejection.tooManyPixels),
    );
  });

  test('WebP animation scan stays in bounds near the 1 KB boundary', () {
    // Regression guard: files of exactly 1024-1026 bytes used to read
    // past the end of the buffer.
    for (final length in [1023, 1024, 1025, 1026, 1027]) {
      final bytes = Uint8List(length);
      bytes.setRange(0, 4, 'RIFF'.codeUnits);
      bytes.setRange(8, 12, 'WEBP'.codeUnits);
      // Not a decodable WebP; must fail as corrupt, never as RangeError.
      expect(
        () => validator.validate(bytes),
        rejects(ImageRejection.corrupt),
        reason: 'length $length',
      );
    }
  });

  group('EXIF orientation', () {
    test('a rotated JPEG reports the dimensions it is displayed at', () {
      // The SOF header says 800x600; orientation 6 asks for a quarter
      // turn, and every consumer (the decoder, the thumbnail, Flutter's
      // Image.file) shows 600x800.
      for (final orientation in [5, 6, 7, 8]) {
        final result = validator.validate(
          rotatedJpegBytes(orientation: orientation, width: 800, height: 600),
        );
        expect(result.width, 600, reason: 'orientation $orientation');
        expect(result.height, 800, reason: 'orientation $orientation');
      }
    });

    test('an unrotated JPEG keeps its header dimensions', () {
      for (final orientation in [1, 2, 3, 4]) {
        final result = validator.validate(
          rotatedJpegBytes(orientation: orientation, width: 800, height: 600),
        );
        expect(result.width, 800, reason: 'orientation $orientation');
        expect(result.height, 600, reason: 'orientation $orientation');
      }
    });

    test('animations keep the canvas dimensions from the header', () {
      // An animation frame can be a sub-rect of the canvas, so a frame
      // smaller than the header is not evidence of rotation.
      final result = validator.validate(
        animatedGifBytes(frames: 4, width: 16, height: 12),
      );
      expect(result.width, 16);
      expect(result.height, 12);
    });

    test('a square rotated image is unambiguous', () {
      final result = validator.validate(
        rotatedJpegBytes(orientation: 6, width: 64, height: 64),
      );
      expect(result.width, 64);
      expect(result.height, 64);
    });
  });

  group('HEIF sniffing', () {
    test('a major HEIC brand asks for conversion', () {
      expect(
        () => validator.validate(ftypBytes(majorBrand: 'heic')),
        rejects(ImageRejection.needsConversion),
      );
    });

    test('a HEIC brand in the compatible list asks for conversion', () {
      expect(
        () => validator.validate(
          ftypBytes(majorBrand: 'mif1', compatibleBrands: const ['heic']),
        ),
        rejects(ImageRejection.needsConversion),
      );
    });

    test('AVIF asks for conversion', () {
      expect(
        () => validator.validate(
          ftypBytes(majorBrand: 'avif', compatibleBrands: const ['avif']),
        ),
        rejects(ImageRejection.needsConversion),
      );
    });

    test('a non-HEIF ftyp box is merely unsupported', () {
      expect(
        () => validator.validate(
          ftypBytes(majorBrand: 'mp42', compatibleBrands: const ['isom']),
        ),
        rejects(ImageRejection.unsupportedFormat),
      );
    });

    test('a truncated ftyp box is unsupported, not a crash', () {
      for (final length in [12, 15, 16, 17]) {
        expect(
          () => validator.validate(ftypBytes(truncateTo: length)),
          rejects(
            length < 16
                ? ImageRejection.unsupportedFormat
                : ImageRejection.needsConversion,
          ),
          reason: 'length $length',
        );
      }
    });

    test('an absurd declared box size terminates the brand scan', () {
      // The declared length is attacker-controlled; the scan must be
      // bounded by the buffer, not by what the file claims.
      expect(
        () => validator.validate(
          ftypBytes(
            majorBrand: 'mp42',
            compatibleBrands: const ['isom'],
            declaredSize: 0x7FFFFFFF,
          ),
        ),
        rejects(ImageRejection.unsupportedFormat),
      );
    });

    test('supported formats still sniff ahead of the ftyp check', () {
      expect(validator.validate(pngBytes()).mimeType, 'image/png');
      expect(validator.validate(staticGifBytes()).mimeType, 'image/gif');
      expect(validator.validate(jpegBytes()).mimeType, 'image/jpeg');
    });
  });

  test('grayscale-plus-alpha PNGs report hasAlpha', () {
    final source = img.Image(width: 4, height: 4, numChannels: 2);
    final bytes = img.encodePng(source);
    final result = validator.validate(Uint8List.fromList(bytes));
    expect(result.hasAlpha, isTrue);
  });
}
