import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/app/floating_dock.dart';

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

  Future<void> settle(WidgetTester tester) async {
    await pumpUntil(tester, () => find.byType(Scaffold).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder destination(String label) => find.descendant(
    of: find.byType(FloatingDock),
    matching: find.text(label),
  );

  testWidgets('bottom bar switches between the four tabs', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Meme Library'), findsOneWidget);

    await tester.tap(destination('Stickers'));
    await tester.pumpAndSettle();
    expect(find.text('No sticker packs yet'), findsOneWidget);

    await tester.tap(destination('Tags'));
    await tester.pumpAndSettle();
    expect(find.text('No tags yet'), findsOneWidget);

    await tester.tap(destination('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Backup'), findsOneWidget);

    await tester.tap(destination('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Meme Library'), findsOneWidget);
  });

  testWidgets('the sticker pack screen keeps the bottom bar visible', (
    tester,
  ) async {
    await tester.runAsync(() => harness.stickerPacks.createPack('Reactions'));

    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(destination('Stickers'));
    await pumpUntilFound(tester, find.text('Reactions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reactions'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add memes'), findsOneWidget);
    expect(find.byType(FloatingDock), findsOneWidget);

    // Back pops the pack screen, not the tab.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('New sticker pack'), findsOneWidget);
    expect(find.byType(FloatingDock), findsOneWidget);
  });

  testWidgets('the emoji sheet blocks the bottom bar', (tester) async {
    await tester.runAsync(() async {
      final meme = await harnessImport(harness, seed: 1);
      final pack = await harness.stickerPacks.createPack('Reactions');
      await harness.stickerPacks.addMemes(pack.id, [meme.id]);
    });

    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(destination('Stickers'));
    await pumpUntilFound(tester, find.text('Reactions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reactions'));
    await pumpUntilFound(tester, find.byTooltip('Add memes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('Save emojis'), findsOneWidget);

    // The sheet lives on the root navigator, so it (and its barrier) covers
    // the navigation bar: this tap cannot switch tabs.
    await tester.tap(destination('Library'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Save emojis'), findsOneWidget);
    final dock = tester.widget<FloatingDock>(find.byType(FloatingDock));
    expect(dock.selectedIndex, 1);

    await tester.tap(find.text('Save emojis'));
    await tester.pumpAndSettle();
    expect(find.text('Save emojis'), findsNothing);
    expect(find.byTooltip('Add memes'), findsOneWidget);
  });

  testWidgets('back on another tab leaves the sticker stack alone', (
    tester,
  ) async {
    await tester.runAsync(() => harness.stickerPacks.createPack('Reactions'));

    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(destination('Stickers'));
    await pumpUntilFound(tester, find.text('Reactions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reactions'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add memes'), findsOneWidget);

    await tester.tap(destination('Library'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Meme Library'), findsOneWidget);

    // The hidden sticker stack was not popped by back on the library tab.
    await tester.tap(destination('Stickers'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add memes'), findsOneWidget);
  });

  testWidgets('library search text survives a tab round-trip', (tester) async {
    await tester.runAsync(() => harnessImport(harness, seed: 1));

    await tester.pumpWidget(app());
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'doge');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(destination('Stickers'));
    await tester.pumpAndSettle();
    await tester.tap(destination('Library'));
    await tester.pumpAndSettle();

    expect(find.text('doge'), findsOneWidget);
  });

  testWidgets('the add button opens the sheet without switching tabs', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byTooltip('Add meme'));
    await tester.pumpAndSettle();

    expect(find.text('Save from photos'), findsOneWidget);
    expect(find.text('Paste image'), findsOneWidget);
    expect(find.text('Save from link'), findsOneWidget);
    final dock = tester.widget<FloatingDock>(find.byType(FloatingDock));
    expect(dock.selectedIndex, 0);
  });

  testWidgets('the search FAB focuses the search bar', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.focusNode!.hasFocus, isTrue);
  });

  testWidgets('back on another tab returns to the library', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(destination('Tags'));
    await tester.pumpAndSettle();
    expect(find.text('No tags yet'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Meme Library'), findsOneWidget);
    expect(find.text('No tags yet'), findsNothing);
  });
}
