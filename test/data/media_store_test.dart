import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:meme_library/src/data/image_validator.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';

void main() {
  late Directory root;
  late MediaStore store;
  const validator = ImageValidator();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media_store_test');
    store = MediaStore(root, thumbnailMaxDimension: 16);
    await store.init();
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'stores original and thumbnail under hash-keyed relative paths',
    () async {
      final image = validator.validate(
        pngBytes(width: 64, height: 32, seed: 1),
      );
      final stored = await store.store(image);

      expect(stored.sha256, MediaStore.hashBytes(image.bytes));
      expect(stored.relativePath, 'originals/${stored.sha256}.png');
      expect(stored.thumbnailPath, 'thumbs/${stored.sha256}_t.png');

      final original = store.resolve(stored.relativePath);
      expect(await original.readAsBytes(), image.bytes);

      final thumb = img.decodeImage(
        await store.resolve(stored.thumbnailPath).readAsBytes(),
      );
      expect(thumb, isNotNull);
      expect(thumb!.width, lessThanOrEqualTo(16));
      expect(thumb.height, lessThanOrEqualTo(16));
    },
  );

  test('opaque images get JPEG thumbnails', () async {
    final image = validator.validate(jpegBytes(width: 64, height: 64));
    final stored = await store.store(image);
    expect(stored.thumbnailPath, endsWith('_t.jpg'));
  });

  test('small images are not upscaled', () async {
    final image = validator.validate(pngBytes(width: 4, height: 4));
    final stored = await store.store(image);
    final thumb = img.decodeImage(
      await store.resolve(stored.thumbnailPath).readAsBytes(),
    )!;
    expect(thumb.width, 4);
  });

  test('animated GIFs get animated GIF thumbnails', () async {
    final image = validator.validate(
      animatedGifBytes(frames: 4, width: 64, height: 64),
    );
    final stored = await store.store(image);
    expect(stored.thumbnailPath, endsWith('_t.gif'));

    final thumb = img.decodeImage(
      await store.resolve(stored.thumbnailPath).readAsBytes(),
    )!;
    expect(thumb.numFrames, 4);
    expect(thumb.width, lessThanOrEqualTo(16));
  });

  test('long animations sample down to the frame budget', () async {
    final image = validator.validate(
      animatedGifBytes(frames: MediaStore.maxThumbnailFrames * 2, width: 8),
    );
    final stored = await store.store(image);
    final thumb = img.decodeImage(
      await store.resolve(stored.thumbnailPath).readAsBytes(),
    )!;
    expect(thumb.numFrames, MediaStore.maxThumbnailFrames);
  });

  test('static GIFs get PNG thumbnails', () async {
    final image = validator.validate(staticGifBytes());
    final stored = await store.store(image);
    expect(stored.thumbnailPath, endsWith('_t.png'));
  });

  test('APNGs get animated GIF thumbnails', () async {
    final image = validator.validate(animatedPngBytes(frames: 3));
    final stored = await store.store(image);
    expect(stored.thumbnailPath, endsWith('_t.gif'));
    final thumb = img.decodeImage(
      await store.resolve(stored.thumbnailPath).readAsBytes(),
    )!;
    expect(thumb.numFrames, 3);
  });

  test('staging is empty after a successful store', () async {
    await store.store(validator.validate(pngBytes(seed: 2)));
    final staged = Directory(p.join(root.path, 'staging')).listSync();
    expect(staged, isEmpty);
  });

  test('failed store leaves no residue', () async {
    final image = validator.validate(pngBytes(seed: 3));
    // Make the originals target a file so the rename fails.
    final hash = MediaStore.hashBytes(image.bytes);
    final blocker = Directory(p.join(root.path, 'originals', '$hash.png'));
    await blocker.create(recursive: true);

    await expectLater(store.store(image), throwsA(isA<MediaStoreException>()));
    await blocker.delete();

    expect(Directory(p.join(root.path, 'staging')).listSync(), isEmpty);
    expect(await store.listManagedFiles(), isEmpty);
  });

  test('delete removes both files and tolerates missing files', () async {
    final stored = await store.store(validator.validate(pngBytes(seed: 4)));
    await store.delete(stored.relativePath, stored.thumbnailPath);
    expect(await store.listManagedFiles(), isEmpty);

    // Second delete is a no-op.
    await store.delete(stored.relativePath, stored.thumbnailPath);
  });

  test('clearStaging removes leftover temp files', () async {
    final leftover = File(p.join(root.path, 'staging', 'crash.tmp'));
    await leftover.writeAsString('partial');
    await store.clearStaging();
    expect(await leftover.exists(), isFalse);
  });

  test('listManagedFiles reports stored content as relative paths', () async {
    final a = await store.store(validator.validate(pngBytes(seed: 5)));
    final b = await store.store(validator.validate(jpegBytes(seed: 6)));
    final files = await store.listManagedFiles();
    expect(
      files,
      containsAll([
        a.relativePath,
        a.thumbnailPath,
        b.relativePath,
        b.thumbnailPath,
      ]),
    );
  });
}
