import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../backup/backup_service.dart';
import '../../services/platform/update_installer.dart';
import '../../services/providers.dart';
import '../../update/app_update_service.dart';
import '../library/library_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  double? _downloadProgress;
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    ref.read(updateInstallerProvider).installedVersion().then((version) {
      if (mounted) setState(() => _installedVersion = version);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runBusy(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Widget? details,
  }) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: details == null
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(message), const SizedBox(height: 12), details],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget? _releaseNotes(UpdateInfo info) {
    final notes = info.releaseNotes;
    if (notes == null) return null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Text(notes, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }

  Future<void> _export() => _runBusy(() async {
    try {
      // Commit any delete still inside its undo window so the backup
      // matches what the user sees.
      await ref.read(libraryControllerProvider.notifier).flushPendingDeletes();
      final archive = await ref.read(backupServiceProvider).exportArchive();
      await ref
          .read(shareServiceProvider)
          .shareFile(archive.path, mimeType: 'application/zip');
    } on BackupException catch (e) {
      _showMessage(e.message);
    }
  });

  Future<void> _restore() => _runBusy(() async {
    final picked = await ref.read(backupFilePickerProvider).pickArchive();
    if (picked == null || !mounted) return;

    final confirmed = await _confirm(
      title: 'Restore from backup?',
      message: 'Your current library will be replaced by the backup.',
      confirmLabel: 'Restore',
    );
    if (!confirmed) return;

    try {
      final summary = await ref
          .read(backupServiceProvider)
          .restoreArchive(picked);
      _showMessage(
        'Restored ${summary.memeCount} '
        '${summary.memeCount == 1 ? 'meme' : 'memes'}',
      );
    } on BackupException catch (e) {
      _showMessage(e.message);
    }
  });

  Future<void> _checkForUpdates() => _runBusy(() async {
    // A tap can land before the initState fetch resolves.
    final installed =
        _installedVersion ??
        await ref.read(updateInstallerProvider).installedVersion();
    if (installed == null) {
      _showMessage('Could not determine the installed version.');
      return;
    }
    if (mounted && _installedVersion == null) {
      setState(() => _installedVersion = installed);
    }
    try {
      final check = await ref
          .read(appUpdateServiceProvider)
          .checkForUpdate(installed);
      switch (check) {
        case UpToDate():
          _showMessage("You're on the latest version (v$installed).");
        case UpdateAvailable(:final info):
          await _offerUpdate(info);
      }
    } on UpdateException catch (e) {
      _showMessage(e.message);
    }
  });

  Future<void> _offerUpdate(UpdateInfo info) async {
    if (!mounted) return;
    // iOS cannot install an app from within an app; the release page is
    // the best it can do. Android falls back to it too when a release
    // carries no APK asset.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        info.apkDownloadUrl == null) {
      final view = await _confirm(
        title: 'Update available',
        message: 'Version ${info.tagName} is available.',
        confirmLabel: 'View release',
        details: _releaseNotes(info),
      );
      if (!view) return;
      final opened = await ref
          .read(updateInstallerProvider)
          .openUrl(info.releasePageUrl);
      if (!opened) _showMessage('Could not open the browser.');
      return;
    }

    final size = info.apkSizeBytes;
    final sizeLabel = size == null
        ? ''
        : ' (${(size / (1024 * 1024)).toStringAsFixed(1)} MB)';
    final confirmed = await _confirm(
      title: 'Update available',
      message:
          'Version ${info.tagName}$sizeLabel is ready to download '
          'and install.',
      confirmLabel: 'Download',
      details: _releaseNotes(info),
    );
    if (!confirmed) return;

    final File apk;
    try {
      apk = await ref
          .read(appUpdateServiceProvider)
          .downloadApk(
            info,
            onProgress: (received, total) {
              if (!mounted || total == null) return;
              setState(() => _downloadProgress = received / total);
            },
          );
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
    }

    final install = await ref
        .read(updateInstallerProvider)
        .installApk(apk.path);
    switch (install) {
      case InstallApkResult.started:
        _showMessage('Follow the installer prompt to finish updating.');
      case InstallApkResult.permissionRequested:
        _showMessage('Allow Meme Library to install updates, then try again.');
      case InstallApkResult.failed:
        _showMessage('The update could not be installed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Backup',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Export library'),
                subtitle: const Text('Save everything as a ZIP file'),
                onTap: _export,
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore from backup'),
                subtitle: const Text('Replace this library with a backup'),
                onTap: _restore,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Updates',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.system_update_alt),
                title: const Text('Check for updates'),
                subtitle: Text('Version ${_installedVersion ?? '…'}'),
                onTap: _checkForUpdates,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Memes are stored only on this device. Deleting the app '
                  'deletes your library — keep a backup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: _downloadProgress == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 200,
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Downloading update…',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
