import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/providers.dart';
import 'package:meme_library/src/features/settings/settings_screen.dart';
import 'package:meme_library/src/services/platform/backup_file_picker.dart';

import '../helpers/test_harness.dart';

class _FakePicker implements BackupFilePicker {
  File? file;

  @override
  Future<File?> pickArchive() async => file;
}

void main() {
  late TestHarness harness;
  late _FakePicker picker;

  setUp(() async {
    harness = await TestHarness.create();
    picker = _FakePicker();
  });

  tearDown(() => harness.dispose());

  Widget app() => ProviderScope(
    overrides: [
      ...harness.overrides,
      backupFilePickerProvider.overrideWithValue(picker),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );

  /// Lets real backup IO run to completion, then rebuilds. Backup flows
  /// cross many IO await-boundaries, and each boundary needs a real-async
  /// window followed by a pump to flush fake-zone continuations.
  Future<void> flushIo(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('shows backup actions and the uninstall warning', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Export library'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
    expect(find.textContaining('Deleting the app deletes'), findsOneWidget);
  });

  testWidgets('export shares the archive file', (tester) async {
    await tester.runAsync(() => harnessImport(harness, seed: 1));

    await tester.pumpWidget(app());
    await tester.tap(find.text('Export library'));
    await pumpUntil(tester, () => harness.share.sharedPaths.isNotEmpty);

    expect(harness.share.sharedPaths, hasLength(1));
    expect(harness.share.sharedPaths.single, endsWith('.zip'));
    expect(
      await tester.runAsync(
        () => File(harness.share.sharedPaths.single).exists(),
      ),
      isTrue,
    );
  });

  testWidgets('restore asks for confirmation and reports the result', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await harnessImport(harness, seed: 2);
      // Build a real backup, then wipe the library so restore has an effect.
      final container = ProviderContainer(overrides: harness.overrides);
      picker.file = await container.read(backupServiceProvider).exportArchive();
      container.dispose();
      await harness.repository.replaceAll(const []);
    });

    await tester.pumpWidget(app());
    await tester.tap(find.text('Restore from backup'));
    await pumpUntilFound(tester, find.text('Restore from backup?'));

    expect(find.text('Restore from backup?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await pumpUntilFound(tester, find.text('Restored 1 meme'));

    expect(find.text('Restored 1 meme'), findsOneWidget);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await tester.runAsync(() => harnessImport(harness, seed: 3));
    picker.file = null;

    await tester.pumpWidget(app());
    await tester.tap(find.text('Restore from backup'));
    await flushIo(tester);
    expect(find.text('Restore from backup?'), findsNothing);
    expect(await tester.runAsync(() => harness.repository.memeCount()), 1);
  });
}
