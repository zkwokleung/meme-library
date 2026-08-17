import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/data/sticker_images.dart';

import '../helpers/image_fixtures.dart';

int _alphaAt(Uint8List rgba, int x, int y) =>
    rgba[(y * stickerDimension + x) * 4 + 3];

void main() {
  test('square source fills the whole canvas', () {
    final source = stickerSourceSync(pngBytes(seed: 5));

    expect(source.rgba.length, stickerDimension * stickerDimension * 4);
    expect(_alphaAt(source.rgba, 0, 0), 255);
    expect(_alphaAt(source.rgba, 511, 511), 255);
    expect(_alphaAt(source.rgba, 256, 256), 255);
  });

  test('landscape source is centered with transparent bands', () {
    final source = stickerSourceSync(jpegBytes(width: 100, height: 50));

    // 100x50 scales to 512x256, leaving 128 transparent rows above and
    // below.
    expect(_alphaAt(source.rgba, 256, 0), 0);
    expect(_alphaAt(source.rgba, 256, 127), 0);
    expect(_alphaAt(source.rgba, 256, 128), 255);
    expect(_alphaAt(source.rgba, 256, 256), 255);
    expect(_alphaAt(source.rgba, 256, 511), 0);
  });

  test('EXIF orientation is baked before layout', () {
    final source = stickerSourceSync(
      rotatedJpegBytes(orientation: 6, width: 800, height: 600),
    );

    // The quarter turn makes the image portrait (600x800 -> 384x512), so
    // padding lands left and right rather than top and bottom.
    expect(_alphaAt(source.rgba, 0, 256), 0);
    expect(_alphaAt(source.rgba, 256, 256), 255);
    expect(_alphaAt(source.rgba, 256, 0), 255);
  });

  test('tiny sources upscale to the full sticker size', () {
    final source = stickerSourceSync(webpBytes());

    expect(_alphaAt(source.rgba, 0, 0), 255);
    expect(_alphaAt(source.rgba, 511, 511), 255);
  });

  test('tray icon is a 96x96 PNG', () {
    final source = stickerSourceSync(pngBytes());

    final tray = img.decodePng(source.trayPng);
    expect(tray!.width, trayIconDimension);
    expect(tray.height, trayIconDimension);
  });

  test('animated sources are rejected, not flattened', () {
    expect(
      () => stickerSourceSync(animatedGifBytes()),
      throwsA(
        isA<StickerImageException>().having(
          (e) => e.error,
          'error',
          StickerImageError.animated,
        ),
      ),
    );
  });

  test('undecodable bytes are rejected', () {
    expect(
      () => stickerSourceSync(unknownFormatBytes()),
      throwsA(
        isA<StickerImageException>().having(
          (e) => e.error,
          'error',
          StickerImageError.undecodable,
        ),
      ),
    );
  });

  test('InlineImagePipeline exposes the same work', () async {
    final source = await const InlineImagePipeline().stickerSource(pngBytes());
    expect(source.rgba.length, stickerDimension * stickerDimension * 4);
  });
}
