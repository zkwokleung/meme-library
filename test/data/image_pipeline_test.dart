import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/data/image_validator.dart';
import 'package:meme_library/src/data/media_store.dart';

import '../helpers/image_fixtures.dart';

void main() {
  // Plain `test()`, not `testWidgets()`: there is no fake-async zone here,
  // so the real isolate completes normally.
  const isolate = IsolateImagePipeline();
  const inline = InlineImagePipeline();

  test('probes metadata and hash off the isolate', () async {
    final bytes = pngBytes(width: 12, height: 5, seed: 3);
    final probed = await isolate.probe(bytes);

    expect(probed.sha256, MediaStore.hashBytes(bytes));
    expect(probed.mimeType, 'image/png');
    expect(probed.fileExtension, 'png');
    expect(probed.width, 12);
    expect(probed.height, 5);
    expect(probed.hasAlpha, isTrue);
    expect(probed.isAnimated, isFalse);
  });

  test('rejoining a probe with its bytes reproduces the validated image', () {
    final bytes = jpegBytes(width: 20, height: 10);
    final direct = const ImageValidator().validate(bytes);
    final rejoined = probeImageSync(bytes).toValidatedImage(bytes);

    expect(rejoined.bytes, direct.bytes);
    expect(rejoined.mimeType, direct.mimeType);
    expect(rejoined.fileExtension, direct.fileExtension);
    expect(rejoined.width, direct.width);
    expect(rejoined.height, direct.height);
    expect(rejoined.hasAlpha, direct.hasAlpha);
    expect(rejoined.frameCount, direct.frameCount);
  });

  test('the isolate and inline pipelines agree byte for byte', () async {
    for (final bytes in [
      pngBytes(width: 64, height: 32, seed: 1),
      jpegBytes(width: 64, height: 64),
      animatedGifBytes(frames: 4, width: 32, height: 32),
      rotatedJpegBytes(orientation: 6, width: 80, height: 60),
    ]) {
      final a = await isolate.probe(bytes);
      final b = await inline.probe(bytes);
      expect(a.sha256, b.sha256);
      expect(a.width, b.width);
      expect(a.height, b.height);

      final image = a.toValidatedImage(bytes);
      final ta = await isolate.thumbnail(image, maxDimension: 16);
      final tb = await inline.thumbnail(image, maxDimension: 16);
      expect(ta.extension, tb.extension);
      expect(ta.bytes, tb.bytes);
    }
  });

  test('validation failures cross the isolate boundary intact', () async {
    await expectLater(
      isolate.probe(unknownFormatBytes()),
      throwsA(
        isA<ImageValidationException>().having(
          (e) => e.rejection,
          'rejection',
          ImageRejection.unsupportedFormat,
        ),
      ),
    );
    await expectLater(
      isolate.probe(ftypBytes(majorBrand: 'heic')),
      throwsA(
        isA<ImageValidationException>().having(
          (e) => e.rejection,
          'rejection',
          ImageRejection.needsConversion,
        ),
      ),
    );
  });

  test('a custom validator is honoured across the boundary', () async {
    await expectLater(
      isolate.probe(
        pngBytes(),
        validator: const ImageValidator(maxFileSizeBytes: 16),
      ),
      throwsA(
        isA<ImageValidationException>().having(
          (e) => e.rejection,
          'rejection',
          ImageRejection.tooLarge,
        ),
      ),
    );
  });

  test('thumbnail failures cross the isolate boundary intact', () async {
    // A ValidatedImage whose bytes no decoder accepts can only be built by
    // hand; encodeThumbnailSync must surface a sendable exception (its
    // MediaStoreException carries no `cause`, which is what makes it
    // sendable at all).
    final broken = ValidatedImage(
      bytes: Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        ...List.filled(64, 7),
      ]),
      mimeType: 'image/png',
      fileExtension: 'png',
      width: 1,
      height: 1,
      hasAlpha: false,
      frameCount: 1,
    );
    await expectLater(
      isolate.thumbnail(broken, maxDimension: 16),
      throwsA(isA<MediaStoreException>()),
    );
  });

  test(
    'animated GIFs keep an animated thumbnail through the isolate',
    () async {
      final bytes = animatedGifBytes(frames: 4, width: 64, height: 64);
      final probed = await isolate.probe(bytes);
      final thumb = await isolate.thumbnail(
        probed.toValidatedImage(bytes),
        maxDimension: 16,
      );

      expect(thumb.extension, 'gif');
      final decoded = img.decodeImage(thumb.bytes)!;
      expect(decoded.numFrames, 4);
      expect(decoded.width, lessThanOrEqualTo(16));
    },
  );
}
