import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/import/source_import_services.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/gallery_picker.dart';
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

class _FakeTranscoder implements HeicTranscoder {
  Uint8List? result;
  final calls = <String>[];

  @override
  Future<Uint8List?> transcodeToJpeg(String path) async {
    calls.add(path);
    return result;
  }
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
    coordinator = ImportCoordinator(
      repository: repo,
      mediaStore: media,
      pipeline: const InlineImagePipeline(),
    );
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
      final bad = await stageFile('bad.bin', unknownFormatBytes());

      final outcomes = await service.importShared([
        IncomingSharedFile(path: bad, mimeType: 'application/octet-stream'),
      ]);

      expect(
        (outcomes.single as ImportFailure).reason,
        ImportFailureReason.unsupportedFormat,
      );
      expect(File(bad).existsSync(), isFalse);
    });

    test('shared animated GIFs import and stay animated', () async {
      final service = ShareImportService(coordinator);
      final path = await stageFile('reaction.gif', animatedGifBytes(frames: 3));

      final outcomes = await service.importShared([
        IncomingSharedFile(path: path, mimeType: 'image/gif'),
      ]);

      final meme = (outcomes.single as ImportSuccess).meme;
      expect(meme.mimeType, 'image/gif');
      expect(meme.thumbnailPath, endsWith('_t.gif'));
    });
  });

  group('GalleryImportService', () {
    late _FakeTranscoder transcoder;
    late GalleryImportService service;
    late Directory picks;

    setUp(() async {
      transcoder = _FakeTranscoder();
      service = GalleryImportService(coordinator, transcoder);
      picks = await Directory.systemTemp.createTemp('gallery_picks');
    });

    tearDown(() async {
      if (picks.existsSync()) await picks.delete(recursive: true);
    });

    Future<PickedGalleryImage> stage(
      List<int> bytes, {
      String name = 'pick.bin',
      String? displayName,
    }) async {
      final file = File(p.join(picks.path, name));
      await file.writeAsBytes(bytes, flush: true);
      return PickedGalleryImage(path: file.path, displayName: displayName);
    }

    test('imports picked images and removes the temporary copies', () async {
      final picked = [
        await stage(pngBytes(seed: 1), name: 'a.png'),
        await stage(pngBytes(seed: 2), name: 'b.png'),
      ];

      final progress = <(int, int)>[];
      final outcomes = await service.importPicked(
        picked,
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(outcomes.whereType<ImportSuccess>(), hasLength(2));
      expect(progress, [(1, 2), (2, 2)]);
      expect(await repo.memeCount(), 2);
      for (final pick in picked) {
        expect(File(pick.path).existsSync(), isFalse, reason: pick.path);
      }
    });

    test('records the gallery file name as the source reference', () async {
      final picked = await stage(
        pngBytes(seed: 3),
        name: 'x.png',
        displayName: 'IMG_1234.PNG',
      );
      final outcomes = await service.importPicked([picked]);
      final meme = (outcomes.single as ImportSuccess).meme;

      expect(meme.sourceKind, MemeSourceKind.gallery);
      expect(meme.sourceRef, 'IMG_1234.PNG');
    });

    test('a missing pick fails without aborting the batch', () async {
      final outcomes = await service.importPicked([
        const PickedGalleryImage(path: '/nonexistent/gone.png'),
        await stage(pngBytes(seed: 4), name: 'ok.png'),
      ]);

      expect(outcomes.first, isA<ImportFailure>());
      expect(outcomes.last, isA<ImportSuccess>());
      expect(await repo.memeCount(), 1);
    });

    test('HEIC files are transcoded before import', () async {
      transcoder.result = jpegBytes(seed: 5);
      final picked = await stage(
        ftypBytes(majorBrand: 'heic'),
        name: 'IMG_9.heic',
        displayName: 'IMG_9.HEIC',
      );

      final outcome = (await service.importPicked([picked])).single;
      expect(transcoder.calls, [picked.path]);

      final meme = (outcome as ImportSuccess).meme;
      expect(meme.mimeType, 'image/jpeg');
      // Provenance keeps the original name even though the stored file is
      // now a JPEG.
      expect(meme.sourceRef, 'IMG_9.HEIC');
    });

    test('non-HEIF picks never reach the transcoder', () async {
      await service.importPicked([
        await stage(pngBytes(seed: 6), name: 'plain.png'),
      ]);
      expect(transcoder.calls, isEmpty);
    });

    test(
      'a transcoder that cannot decode reports an actionable failure',
      () async {
        transcoder.result = null;
        final picked = await stage(
          ftypBytes(majorBrand: 'heic'),
          name: 'bad.heic',
        );

        final outcome = (await service.importPicked([picked])).single;
        expect(
          outcome,
          isA<ImportFailure>()
              .having(
                (f) => f.reason,
                'reason',
                ImportFailureReason.unsupportedFormat,
              )
              .having((f) => f.message, 'message', contains('converted')),
        );
        expect(File(picked.path).existsSync(), isFalse);
      },
    );

    test('temporary copies are removed even when the import fails', () async {
      final picked = await stage(unknownFormatBytes(), name: 'garbage.png');
      final outcome = (await service.importPicked([picked])).single;

      expect(outcome, isA<ImportFailure>());
      expect(File(picked.path).existsSync(), isFalse);
      expect(await repo.memeCount(), 0);
    });

    test('an empty selection is a no-op', () async {
      expect(await service.importPicked(const []), isEmpty);
      expect(await repo.memeCount(), 0);
    });
  });
}
