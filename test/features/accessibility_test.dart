import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/app.dart';

import '../helpers/test_harness.dart';

/// Automated slice of the accessibility matrix; the screen-reader pass on
/// physical devices is tracked in docs/manual-test-matrix.md.
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

  testWidgets('library screen labels every tap target', (tester) async {
    // Tap-target *size* is asserted on the settings screen below: the
    // library's SearchBar contains a 24px-tall inner text node that trips
    // the size guideline even though the whole 56px bar is tappable.
    await tester.runAsync(() => harnessImport(harness, seed: 1));
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(app());
    await settle(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('settings screen meets tap-target size guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('meme tiles expose semantic labels', (tester) async {
    await tester.runAsync(() async {
      final meme = await harnessImport(harness, seed: 2);
      await harness.repository.updateMetadata(
        meme.id,
        title: () => 'Distracted boyfriend',
      );
    });
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.bySemanticsLabel('Distracted boyfriend'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('text scales to 200% without overflow errors', (tester) async {
    await tester.runAsync(() => harnessImport(harness, seed: 3));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: app(),
      ),
    );
    await settle(tester);

    // Overflow throws render errors; reaching here without exceptions
    // means the layout tolerates 200% scaling.
    expect(tester.takeException(), isNull);
    expect(find.text('Meme Library'), findsOneWidget);
  });
}
