import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/providers.dart';
import 'package:meme_library/src/features/settings/settings_screen.dart';
import 'package:meme_library/src/services/platform/backup_file_picker.dart';
import 'package:meme_library/src/services/platform/update_installer.dart';
import 'package:meme_library/src/update/app_update_service.dart';

import '../helpers/test_harness.dart';

class _FakePicker implements BackupFilePicker {
  File? file;

  @override
  Future<File?> pickArchive() async => file;
}

class _FakeUpdateService implements AppUpdateService {
  UpdateCheck check = const UpToDate();
  UpdateException? checkError;
  File apk = File('/tmp/fake/v9.9.9.apk');

  @override
  Future<UpdateCheck> checkForUpdate(String installedVersion) async {
    final error = checkError;
    if (error != null) throw error;
    return check;
  }

  @override
  Future<File> downloadApk(
    UpdateInfo info, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    onProgress?.call(50, 100);
    return apk;
  }
}

const _releasePageUrl =
    'https://github.com/zkwokleung/meme-library/releases/v9.9.9';

const _update = UpdateInfo(
  latestVersion: SemVer(9, 9, 9),
  tagName: 'v9.9.9',
  releasePageUrl: _releasePageUrl,
  releaseNotes: 'Bug fixes and shiny new memes.',
  apkDownloadUrl: 'https://example.com/v9.9.9.apk',
  apkSizeBytes: 10 * 1024 * 1024,
);

void main() {
  late TestHarness harness;
  late _FakePicker picker;
  late _FakeUpdateService updates;

  setUp(() async {
    harness = await TestHarness.create();
    picker = _FakePicker();
    updates = _FakeUpdateService();
  });

  tearDown(() => harness.dispose());

  Widget app() => ProviderScope(
    overrides: [
      ...harness.overrides,
      backupFilePickerProvider.overrideWithValue(picker),
      appUpdateServiceProvider.overrideWithValue(updates),
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

  testWidgets('shows the installed version under the update tile', (
    tester,
  ) async {
    harness.updateInstaller.version = '1.2.3';

    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsOneWidget);
  });

  testWidgets('an up-to-date check reports it in a snackbar', (tester) async {
    updates.check = const UpToDate();

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('Check for updates'));
    await pumpUntilFound(tester, find.textContaining('latest version'));

    expect(find.textContaining("You're on the latest version"), findsOneWidget);
  });

  testWidgets('a check failure surfaces the error message', (tester) async {
    updates.checkError = const UpdateException('GitHub rate limit reached.');

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('Check for updates'));
    await pumpUntilFound(tester, find.text('GitHub rate limit reached.'));

    expect(find.text('GitHub rate limit reached.'), findsOneWidget);
  });

  testWidgets(
    'Android downloads the apk and launches the installer',
    (tester) async {
      updates.check = const UpdateAvailable(_update);

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('Update available'));

      expect(find.textContaining('v9.9.9'), findsOneWidget);
      expect(find.textContaining('10.0 MB'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await pumpUntilFound(tester, find.textContaining('installer prompt'));

      expect(harness.updateInstaller.installedPaths, [updates.apk.path]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'the update dialog shows the release notes',
    (tester) async {
      updates.check = const UpdateAvailable(_update);

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('Update available'));

      expect(find.text('Bug fixes and shiny new memes.'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a missing install permission tells the user to retry',
    (tester) async {
      updates.check = const UpdateAvailable(_update);
      harness.updateInstaller.installResult =
          InstallApkResult.permissionRequested;

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('Download'));
      await tester.tap(find.text('Download'));
      await pumpUntilFound(tester, find.textContaining('Allow Meme Library'));

      expect(find.textContaining('Allow Meme Library'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'cancelling the download dialog installs nothing',
    (tester) async {
      updates.check = const UpdateAvailable(_update);

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await flushIo(tester);

      expect(harness.updateInstaller.installedPaths, isEmpty);
      expect(harness.updateInstaller.openedUrls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS opens the release page instead of downloading',
    (tester) async {
      updates.check = const UpdateAvailable(_update);

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('View release'));
      await tester.tap(find.text('View release'));
      await pumpUntil(
        tester,
        () => harness.updateInstaller.openedUrls.isNotEmpty,
      );

      expect(harness.updateInstaller.openedUrls, [_releasePageUrl]);
      expect(harness.updateInstaller.installedPaths, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a release without an apk asset falls back to the page',
    (tester) async {
      updates.check = const UpdateAvailable(
        UpdateInfo(
          latestVersion: SemVer(9, 9, 9),
          tagName: 'v9.9.9',
          releasePageUrl: _releasePageUrl,
        ),
      );

      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Check for updates'));
      await pumpUntilFound(tester, find.text('View release'));
      await tester.tap(find.text('View release'));
      await pumpUntil(
        tester,
        () => harness.updateInstaller.openedUrls.isNotEmpty,
      );

      expect(harness.updateInstaller.openedUrls, [_releasePageUrl]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
