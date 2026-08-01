import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/providers.dart';
import 'package:meme_library/src/domain/library_query.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/incoming_share_service.dart';
import 'package:meme_library/src/services/providers.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

/// End-to-end regression protection for the critical user workflows,
/// exercised through the same providers the app wires at startup.
/// Native-only behavior (real pasteboards, share sheets, intents) is
/// covered by docs/manual-test-matrix.md.
void main() {
  late TestHarness harness;
  late ProviderContainer container;

  setUp(() async {
    harness = await TestHarness.create();
    container = ProviderContainer(overrides: harness.overrides);
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  test(
    'import → tag → search → copy → share → delete → backup → restore',
    () async {
      // -- Import from two sources, with a duplicate resolving cleanly.
      harness.clipboard.content = ClipboardImage(
        bytes: pngBytes(seed: 1),
        suggestedName: 'dog.png',
      );
      final clipboardImport = await container
          .read(clipboardImportServiceProvider)
          .importFromClipboard();
      final first = (clipboardImport as ImportSuccess).meme;

      final duplicate =
          await container
                  .read(importCoordinatorProvider)
                  .importBytes(pngBytes(seed: 1), sourceKind: first.sourceKind)
              as ImportSuccess;
      expect(duplicate.wasDuplicate, isTrue);

      final second =
          (await container
                  .read(importCoordinatorProvider)
                  .importBytes(
                    jpegBytes(seed: 2),
                    sourceKind: first.sourceKind,
                  ))
              as ImportSuccess;

      final repository = container.read(libraryRepositoryProvider);
      expect(await repository.memeCount(), 2);

      // -- Tag and edit metadata.
      final tag = await repository.ensureTag('dogs');
      await repository.setTags(first.id, [tag]);
      await repository.updateMetadata(first.id, title: () => 'Good boy');

      // -- Search finds by title and by tag; filters combine.
      final byTitle = await repository.query(
        const LibraryQuery(searchText: 'good'),
      );
      expect(byTitle.items.single.id, first.id);
      final byTag = await repository.query(LibraryQuery(tagIds: {tag.id}));
      expect(byTag.items.single.id, first.id);

      // -- Copy places original bytes on the clipboard.
      final media = container.read(mediaStoreProvider);
      final originalBytes = await media
          .resolve(byTitle.items.single.relativePath)
          .readAsBytes();
      final copied = await container
          .read(clipboardServiceProvider)
          .writeImage(ClipboardImage(bytes: originalBytes));
      expect(copied, isTrue);
      expect(harness.clipboard.written.single.bytes, originalBytes);

      // -- Share hands the original file to the platform sheet.
      await container
          .read(shareServiceProvider)
          .shareFile(
            media.resolve(second.meme.relativePath).path,
            mimeType: second.meme.mimeType,
          );
      expect(harness.share.sharedPaths.single, endsWith('.jpg'));

      // -- Backup, delete everything, restore, verify identical content.
      final backup = container.read(backupServiceProvider);
      final archive = await backup.exportArchive();

      await repository.deleteMeme(first.id);
      await repository.deleteMeme(second.meme.id);
      expect(await repository.memeCount(), 0);
      expect(await media.listManagedFiles(), isEmpty);

      final summary = await backup.restoreArchive(archive);
      expect(summary.memeCount, 2);

      final restored = await repository.query(const LibraryQuery());
      expect(restored.totalCount, 2);
      final restoredFirst = restored.items.singleWhere((m) => m.id == first.id);
      expect(restoredFirst.title, 'Good boy');
      expect(restoredFirst.tags.single.name, 'dogs');
      expect(
        await media.resolve(restoredFirst.relativePath).readAsBytes(),
        originalBytes,
      );

      // -- Search index survives the restore.
      final afterRestore = await repository.query(
        const LibraryQuery(searchText: 'dogs'),
      );
      expect(afterRestore.items.single.id, first.id);
    },
  );

  test('shared files import through the incoming-share pipeline', () async {
    final staged = File(p.join(harness.root.path, 'incoming.png'));
    await staged.writeAsBytes(pngBytes(seed: 9));

    // Simulates what the native side stages from ACTION_SEND.
    final outcomes = await container
        .read(shareImportServiceProvider)
        .importShared([
          IncomingSharedFile(path: staged.path, mimeType: 'image/png'),
        ]);

    expect(outcomes.single, isA<ImportSuccess>());
    expect(await staged.exists(), isFalse, reason: 'staged copy cleaned up');
  });
}
