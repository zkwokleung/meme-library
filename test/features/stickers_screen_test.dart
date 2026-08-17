import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/features/stickers/stickers_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() => harness.dispose());

  Widget app() => ProviderScope(
    overrides: harness.overrides,
    child: const MaterialApp(home: StickersScreen()),
  );

  testWidgets('shows the empty state before any pack exists', (tester) async {
    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('No sticker packs yet'));

    expect(find.text('No sticker packs yet'), findsOneWidget);
  });

  testWidgets('creates a pack through the dialog', (tester) async {
    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('No sticker packs yet'));

    await tester.tap(find.byTooltip('New sticker pack'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reactions');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Reactions'));

    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('0 stickers'), findsOneWidget);
  });

  testWidgets('a cancelled or blank dialog creates nothing', (tester) async {
    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('No sticker packs yet'));

    await tester.tap(find.byTooltip('New sticker pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New sticker pack'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No sticker packs yet'), findsOneWidget);
  });

  testWidgets('renames a pack from the tile menu', (tester) async {
    await tester.runAsync(() => harness.stickerPacks.createPack('Old name'));

    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('Old name'));

    await tester.tap(find.byTooltip('Pack options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () =>
          find.text('New name').evaluate().isNotEmpty &&
          find.text('Old name').evaluate().isEmpty,
    );

    expect(find.text('New name'), findsOneWidget);
    expect(find.text('Old name'), findsNothing);
  });

  testWidgets('deletes a pack from the tile menu', (tester) async {
    await tester.runAsync(() => harness.stickerPacks.createPack('Doomed'));

    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('Doomed'));

    await tester.tap(find.byTooltip('Pack options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await pumpUntilFound(tester, find.text('No sticker packs yet'));

    expect(find.text('Doomed'), findsNothing);
  });

  testWidgets('list updates when packs change outside the screen', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('No sticker packs yet'));

    await tester.runAsync(() => harness.stickerPacks.createPack('External'));
    await pumpUntilFound(tester, find.text('External'));

    expect(find.text('External'), findsOneWidget);
  });
}
