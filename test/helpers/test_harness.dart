import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/providers.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/features/library/library_controller.dart';
import 'package:meme_library/src/features/library/library_screen.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/gallery_picker.dart';
import 'package:meme_library/src/services/platform/incoming_share_service.dart';
import 'package:meme_library/src/services/platform/share_service.dart';
import 'package:meme_library/src/services/providers.dart';
import 'package:path/path.dart' as p;

import 'image_fixtures.dart';

class FakeClipboardService implements ClipboardService {
  ClipboardImage? content;
  bool writeSupported = true;
  final written = <ClipboardImage>[];

  @override
  Future<ClipboardImage?> readImage() async => content;

  @override
  Future<bool> writeImage(ClipboardImage image) async {
    if (!writeSupported) return false;
    written.add(image);
    return true;
  }
}

class FakeShareService implements ShareService {
  final sharedPaths = <String>[];

  @override
  Future<void> shareFile(String absolutePath, {String? mimeType}) async {
    sharedPaths.add(absolutePath);
  }
}

class FakeIncomingShareService implements IncomingShareService {
  final initial = <IncomingSharedFile>[];
  final controller = StreamController<List<IncomingSharedFile>>.broadcast();

  @override
  Future<List<IncomingSharedFile>> takeInitialShares() async {
    final shares = List.of(initial);
    initial.clear();
    return shares;
  }

  @override
  Stream<List<IncomingSharedFile>> get incomingShares => controller.stream;
}

class FakeGalleryPicker implements GalleryPicker {
  /// Returned as-is by [pickImages]; leave empty to simulate a cancel.
  var picked = <PickedGalleryImage>[];
  var pickCount = 0;

  @override
  Future<List<PickedGalleryImage>> pickImages() async {
    pickCount++;
    return picked;
  }
}

class FakeHeicTranscoder implements HeicTranscoder {
  /// Bytes to hand back; `null` simulates a platform that cannot decode.
  Uint8List? result;
  final calls = <String>[];

  @override
  Future<Uint8List?> transcodeToJpeg(String path) async {
    calls.add(path);
    return result;
  }
}

/// Real storage core on temp dirs + fake platform services.
class TestHarness {
  TestHarness._(
    this.root,
    this.database,
    this.mediaStore,
    this.repository,
    this.clipboard,
    this.share,
    this.incomingShares,
    this.gallery,
    this.heic,
  );

  final Directory root;
  final AppDatabase database;
  final MediaStore mediaStore;
  final DriftLibraryRepository repository;
  final FakeClipboardService clipboard;
  final FakeShareService share;
  final FakeIncomingShareService incomingShares;
  final FakeGalleryPicker gallery;
  final FakeHeicTranscoder heic;

  static Future<TestHarness> create() async {
    final root = await Directory.systemTemp.createTemp('meme_harness');
    final database = AppDatabase.inMemory();
    final mediaStore = MediaStore(root);
    await mediaStore.init();
    final repository = DriftLibraryRepository(database, mediaStore);
    return TestHarness._(
      root,
      database,
      mediaStore,
      repository,
      FakeClipboardService(),
      FakeShareService(),
      FakeIncomingShareService(),
      FakeGalleryPicker(),
      FakeHeicTranscoder(),
    );
  }

  /// Typed by inference: `Override` is not exported by flutter_riverpod 3.3.
  late final overrides = [
    backupWorkDirectoryProvider.overrideWithValue(
      Directory(p.join(root.path, 'backup_work')),
    ),
    // Widget tests run inside a fake-async zone that cannot pump the
    // ReceivePort a real isolate completes through; the work would never
    // finish and every pumpUntil would spin to its iteration limit.
    imagePipelineProvider.overrideWithValue(const InlineImagePipeline()),
    mediaStoreProvider.overrideWithValue(mediaStore),
    libraryRepositoryProvider.overrideWithValue(repository),
    clipboardServiceProvider.overrideWithValue(clipboard),
    shareServiceProvider.overrideWithValue(share),
    incomingShareServiceProvider.overrideWithValue(incomingShares),
    galleryPickerProvider.overrideWithValue(gallery),
    heicTranscoderProvider.overrideWithValue(heic),
  ];

  Future<void> dispose() async {
    await incomingShares.controller.close();
    await database.close();
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // On Windows the image cache can still hold thumbnail file handles;
      // the OS cleans the temp directory eventually.
    }
  }
}

/// Imports a deterministic PNG straight through the coordinator.
Future<Meme> harnessImport(TestHarness harness, {required int seed}) async {
  final coordinator = ImportCoordinator(
    repository: harness.repository,
    mediaStore: harness.mediaStore,
    pipeline: const InlineImagePipeline(),
  );
  final outcome = await coordinator.importBytes(
    pngBytes(seed: seed),
    sourceKind: MemeSourceKind.clipboard,
  );
  return (outcome as ImportSuccess).meme;
}

/// Reads the live library state from a pumped app.
LibraryState harnessLibraryState(WidgetTester tester) {
  final context = tester.element(find.byType(LibraryScreen));
  final container = ProviderScope.containerOf(context);
  return container.read(libraryControllerProvider).requireValue;
}

/// Pumps until [condition] holds. Each iteration opens a real-async window
/// (so file/database IO progresses) and then advances fake-async timers —
/// long IO chains cross one await-boundary per iteration.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxIterations = 400,
}) async {
  for (var i = 0; i < maxIterations && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// Pumps until [finder] matches something.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxIterations = 400,
}) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  maxIterations: maxIterations,
);
