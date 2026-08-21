import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/app/floating_dock.dart';
import 'package:meme_library/src/features/tags/tags_screen.dart';

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

  Future<void> openTagsTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingDock),
        matching: find.text('Tags'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Two memes: "popular" is on both, "rare" on one.
  Future<void> seedTags() async {
    final a = await harnessImport(harness, seed: 1);
    final b = await harnessImport(harness, seed: 2);
    final popular = await harness.repository.ensureTag('popular');
    final rare = await harness.repository.ensureTag('rare');
    await harness.repository.setTags(a.id, [popular, rare]);
    await harness.repository.setTags(b.id, [popular]);
  }

  double chipFontSize(WidgetTester tester, String name) {
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(ActionChip), matching: find.text(name)),
    );
    return text.style!.fontSize!;
  }

  test('tagFontSize scales logarithmically between 14 and 28', () {
    expect(tagFontSize(1, 1), 14);
    expect(tagFontSize(5, 5), 28);
    expect(
      tagFontSize(2, 5),
      closeTo(14 + 14 * (math.log(3) / math.log(6)), 0.001),
    );
  });

  testWidgets('tags are sized by how many memes carry them', (tester) async {
    await tester.runAsync(seedTags);

    await tester.pumpWidget(app());
    await settle(tester);
    await openTagsTab(tester);

    expect(
      chipFontSize(tester, 'rare'),
      closeTo(14 + 14 * (math.log(2) / math.log(3)), 0.001),
    );
    expect(chipFontSize(tester, 'popular'), 28);
  });

  testWidgets('tapping a tag filters the library', (tester) async {
    await tester.runAsync(seedTags);

    await tester.pumpWidget(app());
    await settle(tester);
    await openTagsTab(tester);

    await tester.tap(
      find.descendant(of: find.byType(ActionChip), matching: find.text('rare')),
    );
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => harnessLibraryState(tester).items.length == 1,
    );

    expect(find.text('Meme Library'), findsOneWidget);
    final state = harnessLibraryState(tester);
    expect(state.tagIds, hasLength(1));
    expect(state.items, hasLength(1));
  });

  testWidgets('long-press renames a tag', (tester) async {
    await tester.runAsync(seedTags);

    await tester.pumpWidget(app());
    await settle(tester);
    await openTagsTab(tester);

    await tester.longPress(
      find.descendant(of: find.byType(ActionChip), matching: find.text('rare')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'unique');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    // The dialog's own TextField also matches 'unique', so wait for the
    // old chip to go instead.
    await pumpUntil(tester, () => find.text('rare').evaluate().isEmpty);

    expect(find.text('rare'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ActionChip),
        matching: find.text('unique'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('long-press deletes a tag after confirmation', (tester) async {
    await tester.runAsync(seedTags);

    await tester.pumpWidget(app());
    await settle(tester);
    await openTagsTab(tester);

    await tester.longPress(
      find.descendant(of: find.byType(ActionChip), matching: find.text('rare')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "rare"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpUntil(tester, () => find.text('rare').evaluate().isEmpty);

    expect(find.text('rare'), findsNothing);
    final tags = await tester.runAsync(() => harness.repository.allTags());
    expect(tags!.map((t) => t.name), ['popular']);
  });

  testWidgets('shows the empty state without tags', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await openTagsTab(tester);

    expect(find.text('No tags yet'), findsOneWidget);
  });
}
