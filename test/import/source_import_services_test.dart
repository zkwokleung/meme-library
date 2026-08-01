import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/import/source_import_services.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/incoming_share_service.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';

class _FakeClipboard implements ClipboardService {
  _FakeClipboard(this.image, {this.throwOnRead = false});

  ClipboardImage? image;
  bool throwOnRead;

  @override
  Future<ClipboardImage?> readImage() async {
    if (throwOnRead) throw StateError('denied');
    return image;
  }

  @override
  Future<bool> writeImage(ClipboardImage image) async => true;
}

void main() {
  late Directory root;
  late AppDatabase db;
  late DriftLibraryRepository repo;
  late MediaStore media;
  late ImportCoordinator coordinator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('source_import_test');
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

  group('ClipboardImportService', () {
    test('imports a clipboard image', () async {
      final service = ClipboardImportService(
        coordinator,
        _FakeClipboard(
          ClipboardImage(bytes: pngBytes(seed: 1), suggestedName: 'copy.png'),
        ),
      );

      final success = await service.importFromClipboard() as ImportSuccess;
      expect(success.meme.sourceRef, 'copy.png');
      expect(await repo.memeCount(), 1);
    });

    test('empty clipboard is an actionable failure', () async {
      final service = ClipboardImportService(coordinator, _FakeClipboard(null));
      final failure = await service.importFromClipboard() as ImportFailure;
      expect(failure.reason, ImportFailureReason.emptySource);
      expect(failure.message, contains('Copy an image'));
    });

    test('clipboard read errors do not crash the import', () async {
      final service = ClipboardImportService(
        coordinator,
        _FakeClipboard(null, throwOnRead: true),
      );
      final failure = await service.importFromClipboard() as ImportFailure;
      expect(failure.reason, ImportFailureReason.unknown);
    });
  });

  group('ShareImportService', () {
    Future<String> stageFile(String name, Uint8List bytes) async {
      final file = File(p.join(root.path, name));
      await file.writeAsBytes(bytes);
      return file.path;
    }

    test('imports staged files and removes them afterwards', () async {
      final service = ShareImportService(coordinator);
      final pathA = await stageFile('a.png', pngBytes(seed: 2));
      final pathB = await stageFile('b.jpg', jpegBytes(seed: 3));

      final progress = <(int, int)>[];
      final outcomes = await service.importShared([
        IncomingSharedFile(path: pathA, mimeType: 'image/png'),
        IncomingSharedFile(path: pathB, mimeType: 'image/jpeg'),
      ], onProgress: (done, total) => progress.add((done, total)));

      expect(outcomes.whereType<ImportSuccess>(), hasLength(2));
      expect(progress, [(1, 2), (2, 2)]);
      expect(await repo.memeCount(), 2);
      // Staged copies are cleaned up even on success.
      expect(File(pathA).existsSync(), isFalse);
      expect(File(pathB).existsSync(), isFalse);
    });

    test('missing staged files fail without aborting the batch', () async {
      final service = ShareImportService(coordinator);
      final good = await stageFile('good.png', pngBytes(seed: 4));

      final outcomes = await service.importShared([
        const IncomingSharedFile(path: '/nope/missing.png'),
        IncomingSharedFile(path: good),
      ]);

      expect(outcomes[0], isA<ImportFailure>());
      expect(outcomes[1], isA<ImportSuccess>());
      expect(await repo.memeCount(), 1);
    });

    test('invalid staged content is cleaned up and reported', () async {
      final service = ShareImportService(coordinator);
      final bad = await stageFile('bad.gif', gifBytes());

      final outcomes = await service.importShared([
        IncomingSharedFile(path: bad, mimeType: 'image/gif'),
      ]);

      expect(
        (outcomes.single as ImportFailure).reason,
        ImportFailureReason.unsupportedFormat,
      );
      expect(File(bad).existsSync(), isFalse);
    });
  });
}
