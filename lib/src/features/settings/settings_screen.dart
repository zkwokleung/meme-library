import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../backup/backup_service.dart';
import '../../services/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

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

  Future<void> _export() => _runBusy(() async {
    try {
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'Your current library will be replaced by the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
