import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/import/import_coordinator.dart';

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

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

  testWidgets('bulk select adds static memes to a new sticker pack', (
    tester,
  ) async {
    await tester.runAsync(() async {
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
    });

    await tester.pumpWidget(app());
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('Meme').evaluate().length == 3,
    );

    final tiles = find.bySemanticsLabel('Meme');
    await tester.longPress(tiles.first);
    await tester.pump();
    await tester.tap(tiles.at(1));
    await tester.pump();
    await tester.tap(tiles.at(2));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to sticker pack'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New pack…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Reactions');
    await tester.tap(find.text('Save'));
    await pumpUntilFound(tester, find.text('2 added, 1 animated skipped'));

    // Selection mode ended and the pack holds only the static memes.
    expect(find.text('3 selected'), findsNothing);
    final packs = await tester.runAsync(() => harness.stickerPacks.allPacks());
    expect(packs!.single.name, 'Reactions');
    expect(packs.single.stickerCount, 2);
  });

  testWidgets('an all-animated selection is rejected with a message', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final coordinator = ImportCoordinator(
        repository: harness.repository,
        mediaStore: harness.mediaStore,
        pipeline: const InlineImagePipeline(),
      );
      await coordinator.importBytes(
        animatedGifBytes(),
        sourceKind: MemeSourceKind.clipboard,
      );
    });

    await tester.pumpWidget(app());
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('Meme').evaluate().isNotEmpty,
    );

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pump();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to sticker pack'));
    await pumpUntilFound(
      tester,
      find.text('Animated memes cannot become stickers'),
    );

    expect(
      await tester.runAsync(() => harness.stickerPacks.allPacks()),
      isEmpty,
    );
  });

  testWidgets('an existing pack can be chosen from the sheet', (tester) async {
    final packId = await tester
        .runAsync(() async {
          await harnessImport(harness, seed: 1);
          return (await harness.stickerPacks.createPack('Existing')).id;
        })
        .then((id) => id!);

    await tester.pumpWidget(app());
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('Meme').evaluate().isNotEmpty,
    );

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pump();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to sticker pack'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Existing'));
    await pumpUntilFound(tester, find.text('1 added'));

    final pack = await tester.runAsync(
      () => harness.stickerPacks.packById(packId),
    );
    expect(pack!.items, hasLength(1));
  });
}
