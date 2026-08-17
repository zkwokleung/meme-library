import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';

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
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('bottom bar switches between the four tabs', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Meme Library'), findsOneWidget);

    await tester.tap(destination('Stickers'));
    await tester.pumpAndSettle();
    expect(find.text('Stickers are coming soon'), findsOneWidget);

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
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
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
