import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';

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

  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(app());
    await flushIo(tester);

    expect(find.text('Meme Library'), findsOneWidget);
    expect(find.text('Your meme stash starts here'), findsOneWidget);
    expect(
      find.text('Save memes from your clipboard, another app, or a link.'),
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

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Added to your library'));

    expect(find.text('Added to your library'), findsOneWidget);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
    // The empty state is replaced by the grid once the reload lands.
    await pumpUntil(tester, () => harnessLibraryState(tester).items.isNotEmpty);
    expect(find.text('Your meme stash starts here'), findsNothing);
  });

  testWidgets('re-importing the same image reports a duplicate', (
    tester,
  ) async {
    harness.clipboard.content = ClipboardImage(bytes: pngBytes(seed: 2));

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Added to your library'));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste image'));
    await pumpUntilFound(tester, find.text('Already in your library'));

    expect(find.text('Already in your library'), findsOneWidget);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
  });

  testWidgets('empty clipboard shows an actionable message', (tester) async {
    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
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

  testWidgets('delete with undo restores the meme', (tester) async {
    final meme = await tester.runAsync(() => harnessImport(harness, seed: 20));

    await tester.pumpWidget(app());
    await flushIo(tester);

    await tester.longPress(find.bySemanticsLabel('Meme').first);
    await tester.pumpAndSettle();
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
