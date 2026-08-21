import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/features/library/library_controller.dart';
import 'package:meme_library/src/features/stickers/meme_picker_screen.dart';
import 'package:meme_library/src/features/stickers/sticker_pack_screen.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/services/platform/sticker_pack_installer.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() => harness.dispose());

  Widget app(String packId) => ProviderScope(
    overrides: harness.overrides,
    child: MaterialApp(home: StickerPackScreen(packId: packId)),
  );

  Future<String> packWithMemes(WidgetTester tester, int count) => tester
      .runAsync(() async {
        final pack = await harness.stickerPacks.createPack('Pack');
        final ids = <String>[];
        for (var i = 0; i < count; i++) {
          ids.add((await harnessImport(harness, seed: i)).id);
        }
        await harness.stickerPacks.addMemes(pack.id, ids);
        return pack.id;
      })
      .then((id) => id!);

  testWidgets('shows the pack grid and disables export below the minimum', (
    tester,
  ) async {
    final packId = await packWithMemes(tester, 2);

    await tester.pumpWidget(app(packId));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 2);

    await tester.tap(find.byTooltip('Add to...'));
    await tester.pumpAndSettle();
    expect(find.text('Add to...'), findsOneWidget);
    final option = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'WhatsApp'),
    );
    expect(option.enabled, isFalse);
  });

  testWidgets('exports to WhatsApp and reports success', (tester) async {
    harness.stickerPackInstaller.exportDirectory = p.join(
      harness.root.path,
      'sticker_packs',
    );
    final packId = await packWithMemes(tester, 3);

    await tester.pumpWidget(app(packId));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 3);

    await tester.tap(find.byTooltip('Add to...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WhatsApp'));
    await pumpUntilFound(tester, find.text('Added to WhatsApp'));

    expect(harness.stickerPackInstaller.enabledPacks, hasLength(1));
    expect(
      Directory(harness.stickerPackInstaller.exportDirectory!).existsSync(),
      isTrue,
    );
  });

  testWidgets('reports a missing WhatsApp install', (tester) async {
    harness.stickerPackInstaller.exportDirectory = p.join(
      harness.root.path,
      'sticker_packs',
    );
    harness.stickerPackInstaller.enableResult =
        InstallStickerPackResult.whatsappNotInstalled;
    final packId = await packWithMemes(tester, 3);

    await tester.pumpWidget(app(packId));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 3);

    await tester.tap(find.byTooltip('Add to...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WhatsApp'));
    await pumpUntilFound(
      tester,
      find.text('Install WhatsApp to add sticker packs'),
    );
  });

  testWidgets('adds memes through the picker, skipping animated ones', (
    tester,
  ) async {
    final packId = await tester
        .runAsync(() async {
          final pack = await harness.stickerPacks.createPack('Pack');
          await harnessImport(harness, seed: 1);
          await harnessImport(harness, seed: 2);
          final coordinator = ImportCoordinator(
            repository: harness.repository,
            mediaStore: harness.mediaStore,
            pipeline: const InlineImagePipeline(),
          );
          await coordinator.importBytes(
            animatedGifBytes(),
            sourceKind: MemeSourceKind.clipboard,
          );
          return pack.id;
        })
        .then((id) => id!);

    await tester.pumpWidget(app(packId));
    await pumpUntilFound(tester, find.byTooltip('Add memes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add memes'));
    await pumpUntilFound(tester, find.text('GIF'));
    await tester.pumpAndSettle();
    expect(find.byType(MemePickerScreen), findsOneWidget);

    // Newest first: the animated meme is tile 0 and cannot be picked; the
    // two static memes follow.
    final tiles = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Image),
    );
    expect(tiles, findsNWidgets(3));
    await tester.tap(tiles.at(1));
    await tester.pump();
    await tester.tap(tiles.at(2));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to pack'));
    await pumpUntilFound(tester, find.text('2 added'));

    final pack = await tester.runAsync(
      () => harness.stickerPacks.packById(packId),
    );
    expect(pack!.items, hasLength(2));
  });

  testWidgets('the picker narrows the grid with search', (tester) async {
    final packId = await tester
        .runAsync(() async {
          final pack = await harness.stickerPacks.createPack('Pack');
          final doge = await harnessImport(harness, seed: 1);
          await harnessImport(harness, seed: 2);
          await harness.repository.updateMetadata(
            doge.id,
            title: () => 'doge wow',
          );
          return pack.id;
        })
        .then((id) => id!);

    await tester.pumpWidget(app(packId));
    await pumpUntilFound(tester, find.byTooltip('Add memes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add memes'));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 2);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'doge');
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 1);

    await tester.enterText(find.byType(SearchBar), 'no such meme');
    await pumpUntilFound(tester, find.text('No memes match your search'));

    await tester.enterText(find.byType(SearchBar), '');
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 2);
  });

  testWidgets('the picker hides memes pending delete-with-undo', (
    tester,
  ) async {
    final packId = await tester
        .runAsync(() async {
          final pack = await harness.stickerPacks.createPack('Pack');
          await harnessImport(harness, seed: 1);
          await harnessImport(harness, seed: 2);
          return pack.id;
        })
        .then((id) => id!);

    await tester.pumpWidget(app(packId));
    await pumpUntilFound(tester, find.byTooltip('Add memes'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StickerPackScreen)),
    );
    final controller = container.read(libraryControllerProvider.notifier);
    await pumpUntil(
      tester,
      () => container.read(libraryControllerProvider).value != null,
    );
    final doomed = container.read(libraryControllerProvider).value!.items.first;
    final hiddenIds = controller.deleteManyWithUndo([doomed]);

    await tester.tap(find.byTooltip('Add memes'));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 1);
    expect(find.byType(Image), findsOneWidget);

    // Cancel the scheduled delete so no timer outlives the test.
    controller.undoDeleteMany(hiddenIds);
    await tester.pumpAndSettle();
  });

  testWidgets('the sticker sheet sets emojis and removes stickers', (
    tester,
  ) async {
    final packId = await packWithMemes(tester, 3);

    await tester.pumpWidget(app(packId));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 3);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '😀 😂');
    await tester.tap(find.text('Save emojis'));
    await tester.pumpAndSettle();

    var pack = await tester.runAsync(
      () => harness.stickerPacks.packById(packId),
    );
    expect(pack!.items.first.emojis, ['😀', '😂']);

    await pumpUntilFound(tester, find.text('😀😂'));
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from pack'));
    await pumpUntil(tester, () => find.byType(Image).evaluate().length == 2);

    pack = await tester.runAsync(() => harness.stickerPacks.packById(packId));
    expect(pack!.items, hasLength(2));
  });

  testWidgets('a deleted pack shows a fallback message', (tester) async {
    await tester.pumpWidget(app('missing'));
    await pumpUntilFound(tester, find.text('This pack no longer exists'));
  });
}
