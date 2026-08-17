import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/gallery_picker.dart';
import 'package:path/path.dart' as p;

import 'helpers/image_fixtures.dart';
import 'helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() => harness.dispose());

  Widget app() => ProviderScope(
    overrides: harness.overrides,
    child: const MemeLibraryApp(bindIncomingShares: false),
  );

  /// Lets real async work (file and database IO) finish, then advances
  /// fake-async timers (debounces) and rebuilds. Import and restore flows
  /// cross many IO await-boundaries, and each boundary needs a real-async
  /// window followed by a pump to flush fake-zone continuations.
  Future<void> flushIo(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add meme'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(app());
    await flushIo(tester);

    expect(find.text('Meme Library'), findsOneWidget);
    expect(find.text('Your meme stash starts here'), findsOneWidget);
    expect(
      find.text(
        'Save memes from your photos, clipboard, another app, or a link.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('imports from clipboard via the add sheet', (tester) async {
    harness.clipboard.content = ClipboardImage(
      bytes: pngBytes(seed: 1),
      suggestedName: 'pasted.png',
    );

    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Added to your library'));

    expect(find.text('Added to your library'), findsOneWidget);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
    // The empty state is replaced by the grid once the reload lands.
    await pumpUntil(tester, () => harnessLibraryState(tester).items.isNotEmpty);
    expect(find.text('Your meme stash starts here'), findsNothing);
  });

  /// Writes [images] into a temp directory and arms the fake picker.
  Future<List<String>> armGalleryPicker(
    WidgetTester tester,
    List<List<int>> images,
  ) async {
    final paths = <String>[];
    final picked = <PickedGalleryImage>[];
    await tester.runAsync(() async {
      final dir = Directory(p.join(harness.root.path, 'picks'));
      await dir.create(recursive: true);
      for (var i = 0; i < images.length; i++) {
        final file = File(p.join(dir.path, 'IMG_$i.png'));
        await file.writeAsBytes(images[i], flush: true);
        paths.add(file.path);
        picked.add(
          PickedGalleryImage(path: file.path, displayName: 'IMG_$i.png'),
        );
      }
    });
    harness.gallery.picked = picked;
    return paths;
  }

  testWidgets('imports from the photo gallery via the add sheet', (
    tester,
  ) async {
    final paths = await armGalleryPicker(tester, [pngBytes(seed: 11)]);

    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Save from photos'));
    await pumpUntilFound(tester, find.text('Added to your library'));

    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
    await pumpUntil(tester, () => harnessLibraryState(tester).items.isNotEmpty);
    final meme = harnessLibraryState(tester).items.single;
    expect(meme.sourceKind, MemeSourceKind.gallery);
    expect(meme.sourceRef, 'IMG_0.png');
    // The picker's temporary copy is ours to clean up.
    expect(File(paths.single).existsSync(), isFalse);
  });

  testWidgets('cancelling the photo picker leaves the library untouched', (
    tester,
  ) async {
    harness.gallery.picked = const [];

    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Save from photos'));
    await flushIo(tester);

    expect(harness.gallery.pickCount, 1);
    // A cancel is not an outcome: no SnackBar at all, least of all an
    // error one.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Nothing to import'), findsNothing);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 0);
    expect(find.text('Your meme stash starts here'), findsOneWidget);
  });

  testWidgets('a multi-photo import summarises added and duplicate counts', (
    tester,
  ) async {
    await armGalleryPicker(tester, [
      pngBytes(seed: 21),
      pngBytes(seed: 22),
      // Same content as the first: resolves as a duplicate.
      pngBytes(seed: 21),
    ]);

    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Save from photos'));
    await pumpUntilFound(tester, find.text('2 added · 1 already saved'));

    expect(await tester.runAsync(() => harness.repository.memeCount()), 2);
  });

  testWidgets('re-importing the same image reports a duplicate', (
    tester,
  ) async {
    harness.clipboard.content = ClipboardImage(bytes: pngBytes(seed: 2));

    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Added to your library'));

    await openAddSheet(tester);
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Already in your library'));

    expect(find.text('Already in your library'), findsOneWidget);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
  });

  testWidgets('empty clipboard shows an actionable message', (tester) async {
    await tester.pumpWidget(app());
    await flushIo(tester);

    await openAddSheet(tester);
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(
      tester,
      find.text('Copy an image first, then try again.'),
    );

    expect(find.text('Copy an image first, then try again.'), findsOneWidget);
  });

  testWidgets('search filters the grid', (tester) async {
    await tester.runAsync(() async {
      final a = await harnessImport(harness, seed: 10);
      await harness.repository.updateMetadata(
        a.id,
        title: () => 'Distracted boyfriend',
      );
      final b = await harnessImport(harness, seed: 11);
      await harness.repository.updateMetadata(
        b.id,
        title: () => 'This is fine',
      );
    });

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.enterText(find.byType(TextField).first, 'distracted');
    // Search debounce (250 ms) is a fake timer; the query is real IO.
    await tester.pump(const Duration(milliseconds: 300));
    await flushIo(tester);

    final state = harnessLibraryState(tester);
    expect(state.items, hasLength(1));
    expect(state.items.single.title, 'Distracted boyfriend');
  });

  Future<void> openBulkMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
  }

  testWidgets('delete with undo restores the meme', (tester) async {
    final meme = await tester.runAsync(() => harnessImport(harness, seed: 20));

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await openBulkMenu(tester);
    await tester.tap(find.text('Delete'));
    await flushIo(tester);

    expect(find.text('Meme deleted'), findsOneWidget);
    expect(harnessLibraryState(tester).items, isEmpty);

    await tester.tap(find.text('Undo'));
    await flushIo(tester);
    expect(harnessLibraryState(tester).items, hasLength(1));

    expect(
      await tester.runAsync(() => harness.repository.memeById(meme!.id)),
      isNotNull,
    );
  });

  testWidgets('bulk delete removes all selected and undo restores them', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await harnessImport(harness, seed: 23);
      await harnessImport(harness, seed: 24);
    });

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Meme').last);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await openBulkMenu(tester);
    await tester.tap(find.text('Delete'));
    await flushIo(tester);

    expect(find.text('2 memes deleted'), findsOneWidget);
    expect(harnessLibraryState(tester).items, isEmpty);

    await tester.tap(find.text('Undo'));
    await flushIo(tester);
    expect(harnessLibraryState(tester).items, hasLength(2));
    expect(await tester.runAsync(() => harness.repository.memeCount()), 2);
  });

  testWidgets('copy is disabled while more than one meme is selected', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await harnessImport(harness, seed: 25);
      await harnessImport(harness, seed: 26);
    });

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    await openBulkMenu(tester);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Copy')).enabled,
      isTrue,
    );
    // Dismiss the menu, extend the selection, and re-open it.
    await tester.tapAt(const Offset(5, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Meme').last);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await openBulkMenu(tester);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Copy')).enabled,
      isFalse,
    );
  });

  testWidgets('bulk share hands every selected file to the share sheet', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await harnessImport(harness, seed: 27);
      await harnessImport(harness, seed: 28);
    });

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Meme').last);
    await tester.pumpAndSettle();

    await openBulkMenu(tester);
    await tester.tap(find.text('Share'));
    await flushIo(tester);

    expect(harness.share.sharedPaths, hasLength(2));
    expect(harnessLibraryState(tester).selectedIds, isEmpty);
  });

  testWidgets('bulk add tag applies the tag to every selected meme', (
    tester,
  ) async {
    final (a, b) = await tester
        .runAsync(() async {
          final a = await harnessImport(harness, seed: 21);
          final b = await harnessImport(harness, seed: 22);
          return (a, b);
        })
        .then((r) => r!);

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Meme').last);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await openBulkMenu(tester);
    await tester.tap(find.text('Add tag'));
    await flushIo(tester);

    await tester.enterText(find.byType(TextField).last, 'reaction');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await flushIo(tester);

    expect(find.text('Added "reaction" to 2 memes'), findsOneWidget);
    expect(harnessLibraryState(tester).selectionMode, isFalse);
    final tagsA = await tester.runAsync(
      () async => (await harness.repository.memeById(a.id))!.tags,
    );
    final tagsB = await tester.runAsync(
      () async => (await harness.repository.memeById(b.id))!.tags,
    );
    expect(tagsA!.map((t) => t.name), ['reaction']);
    expect(tagsB!.map((t) => t.name), ['reaction']);
  });

  testWidgets('selection mode exits via the close button and deselection', (
    tester,
  ) async {
    await tester.runAsync(() => harnessImport(harness, seed: 29));

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('Search'), findsNothing);

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('Meme Library'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);

    // Tapping the only selected tile also leaves selection mode.
    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
    expect(find.text('Meme Library'), findsOneWidget);
  });

  testWidgets('tag chips filter the grid', (tester) async {
    final tagged = await tester.runAsync(() async {
      final tagged = await harnessImport(harness, seed: 30);
      await harnessImport(harness, seed: 31);
      final tag = await harness.repository.ensureTag('reaction');
      await harness.repository.setTags(tagged.id, [tag]);
      return tagged;
    });

    await tester.pumpWidget(app());
    await flushIo(tester);

    expect(find.widgetWithText(FilterChip, 'reaction'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'reaction'));
    await flushIo(tester);

    final state = harnessLibraryState(tester);
    expect(state.items, hasLength(1));
    expect(state.items.single.id, tagged!.id);
  });
}
