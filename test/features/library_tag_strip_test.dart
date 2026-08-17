import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/domain/tag.dart';
import 'package:meme_library/src/features/library/library_screen.dart';

import '../helpers/test_harness.dart';

(Tag, int) entry(String id, int count) => (Tag(id: id, name: id), count);

List<String> ids(List<(Tag, int)> strip) => [for (final (t, _) in strip) t.id];

void main() {
  group('topTagStrip', () {
    test('orders by usage, most used first', () {
      final strip = topTagStrip([
        entry('a', 1),
        entry('b', 3),
        entry('c', 2),
      ], {});
      expect(ids(strip), ['b', 'c', 'a']);
    });

    test('caps at max, breaking count ties alphabetically', () {
      final tags = [for (var i = 5; i >= 0; i--) entry('t$i', 1)];
      final strip = topTagStrip(tags, {}, max: 4);
      expect(ids(strip), ['t0', 't1', 't2', 't3']);
    });

    test('pins selected tags ahead of more-used unselected ones', () {
      final strip = topTagStrip([entry('a', 9), entry('b', 1)], {'b'});
      expect(ids(strip), ['b', 'a']);
    });

    test('keeps a selected tag that falls outside the top slice', () {
      final tags = [for (var i = 0; i < 5; i++) entry('t$i', 5 - i)];
      final strip = topTagStrip(tags, {'t4'}, max: 3);
      expect(ids(strip), ['t4', 't0', 't1']);
    });

    test('shows every selected tag even beyond max', () {
      final strip = topTagStrip(
        [entry('a', 1), entry('b', 1), entry('c', 9)],
        {'a', 'b'},
        max: 1,
      );
      expect(ids(strip), ['a', 'b']);
    });
  });

  group('library tag strip', () {
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
      await pumpUntil(
        tester,
        () => find.byType(Scaffold).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// One meme carrying 25 equally-used tags, so the alphabetical
    /// tie-break decides which 20 make the strip.
    Future<void> seedManyTags() async {
      final meme = await harnessImport(harness, seed: 7);
      final tags = [
        for (var i = 0; i < 25; i++)
          await harness.repository.ensureTag(
            'tag${i.toString().padLeft(2, '0')}',
          ),
      ];
      await harness.repository.setTags(meme.id, tags);
    }

    Future<void> scrollStripToEnd(WidgetTester tester) async {
      await tester.drag(find.byType(FilterChip).first, const Offset(-5000, 0));
      await tester.pump();
    }

    testWidgets('caps at 20 tags with an All tags overflow chip', (
      tester,
    ) async {
      await tester.runAsync(seedManyTags);

      await tester.pumpWidget(app());
      await settle(tester);
      await pumpUntilFound(tester, find.byType(FilterChip));

      await scrollStripToEnd(tester);

      expect(find.text('All tags'), findsOneWidget);
      expect(find.text('tag19'), findsOneWidget);
      expect(find.text('tag20'), findsNothing);
    });

    testWidgets('All tags opens the tag cloud; selecting filters and pins', (
      tester,
    ) async {
      await tester.runAsync(seedManyTags);

      await tester.pumpWidget(app());
      await settle(tester);
      await pumpUntilFound(tester, find.byType(FilterChip));

      await scrollStripToEnd(tester);
      await tester.tap(find.text('All tags'));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.text('tag24'),
        ),
      );
      await tester.pumpAndSettle();
      await pumpUntil(
        tester,
        () => harnessLibraryState(tester).tagIds.isNotEmpty,
      );

      expect(find.text('Meme Library'), findsOneWidget);
      await tester.drag(find.byType(FilterChip).first, const Offset(5000, 0));
      await tester.pump();
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'tag24'),
      );
      expect(chip.selected, isTrue);
    });
  });
}
