import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

  test('rejects GIF and unknown formats', () {
    expect(
      () => validator.validate(gifBytes()),
      rejects(ImageRejection.unsupportedFormat),
    );
    expect(
      () => validator.validate(Uint8List.fromList(List.filled(64, 42))),
      rejects(ImageRejection.unsupportedFormat),
    );
  });

  test('rejects animated WebP', () {
    expect(
      () => validator.validate(animatedWebpBytes()),
      rejects(ImageRejection.animated),
    );
  });

  test('rejects APNG', () {
    expect(
      () => validator.validate(apngBytes()),
      rejects(ImageRejection.animated),
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
}
