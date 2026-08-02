import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/import/import_coordinator.dart';

import '../helpers/image_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late MediaStore media;
  late DriftLibraryRepository repo;
  late ImportCoordinator coordinator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('import_test');
    db = AppDatabase.inMemory();
    media = MediaStore(root);
    await media.init();
    repo = DriftLibraryRepository(db, media);
    coordinator = ImportCoordinator(repository: repo, mediaStore: media);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('imports a valid image end to end', () async {
    final outcome = await coordinator.importBytes(
      pngBytes(seed: 1),
      sourceKind: MemeSourceKind.clipboard,
    );

    final success = outcome as ImportSuccess;
    expect(success.wasDuplicate, isFalse);
    expect(success.meme.mimeType, 'image/png');
    expect(await media.exists(success.meme.relativePath), isTrue);
    expect(await media.exists(success.meme.thumbnailPath), isTrue);
    expect(await repo.memeCount(), 1);
  });

  test('identical content resolves to the existing meme', () async {
    final first =
        await coordinator.importBytes(
              pngBytes(seed: 2),
              sourceKind: MemeSourceKind.clipboard,
            )
            as ImportSuccess;

    final second =
        await coordinator.importBytes(
              pngBytes(seed: 2),
              sourceKind: MemeSourceKind.url,
              sourceRef: 'https://example.com/same.png',
            )
            as ImportSuccess;

    expect(second.wasDuplicate, isTrue);
    expect(second.meme.id, first.meme.id);
    expect(await repo.memeCount(), 1);
  });

  test('invalid data maps to actionable failures', () async {
    Future<ImportFailure> importOf(Uint8List bytes) async =>
        await coordinator.importBytes(
              bytes,
              sourceKind: MemeSourceKind.clipboard,
            )
            as ImportFailure;

    expect(
      (await importOf(Uint8List(0))).reason,
      ImportFailureReason.emptySource,
    );
    expect(
      (await importOf(unknownFormatBytes())).reason,
      ImportFailureReason.unsupportedFormat,
    );
    expect((await importOf(gifBytes())).reason, ImportFailureReason.corrupt);
    expect(
      (await importOf(animatedWebpBytes())).reason,
      ImportFailureReason.corrupt,
    );

    // No partial state from any failure.
    expect(await repo.memeCount(), 0);
    expect(await media.listManagedFiles(), isEmpty);
  });

  test('imports an animated GIF end to end', () async {
    final outcome = await coordinator.importBytes(
      animatedGifBytes(frames: 4),
      sourceKind: MemeSourceKind.share,
    );

    final success = outcome as ImportSuccess;
    expect(success.meme.mimeType, 'image/gif');
    expect(success.meme.relativePath, endsWith('.gif'));
    expect(success.meme.thumbnailPath, endsWith('_t.gif'));
    expect(await media.exists(success.meme.relativePath), isTrue);
    expect(await media.exists(success.meme.thumbnailPath), isTrue);
  });

  test('failure messages are user-readable', () async {
    final failure =
        await coordinator.importBytes(
              unknownFormatBytes(),
              sourceKind: MemeSourceKind.share,
            )
            as ImportFailure;
    expect(failure.message, contains('PNG, JPEG, WebP, and GIF'));
  });

  test('importAll reports progress and mixed outcomes', () async {
    final progress = <(int, int)>[];
    final outcomes = await coordinator.importAll(
      [pngBytes(seed: 3), unknownFormatBytes(), jpegBytes(seed: 4)],
      sourceKind: MemeSourceKind.share,
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(outcomes[0], isA<ImportSuccess>());
    expect(outcomes[1], isA<ImportFailure>());
    expect(outcomes[2], isA<ImportSuccess>());
    expect(progress, [(1, 3), (2, 3), (3, 3)]);
    expect(await repo.memeCount(), 2);
  });
}
