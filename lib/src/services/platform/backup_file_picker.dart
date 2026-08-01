import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// Boundary for picking a backup archive to restore.
abstract interface class BackupFilePicker {
  /// Returns the picked archive, or `null` when the user cancels.
  Future<File?> pickArchive();
}

class FileSelectorBackupFilePicker implements BackupFilePicker {
  const FileSelectorBackupFilePicker();

  @override
  Future<File?> pickArchive() async {
    const zipGroup = XTypeGroup(
      label: 'Backup archive',
      extensions: ['zip'],
      mimeTypes: ['application/zip'],
      uniformTypeIdentifiers: ['public.zip-archive'],
    );
    final picked = await openFile(acceptedTypeGroups: const [zipGroup]);
    return picked == null ? null : File(picked.path);
  }
}
