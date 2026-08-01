import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backup/backup_service.dart';
import '../data/library_repository.dart';
import '../data/media_store.dart';
import '../import/import_coordinator.dart';
import '../import/source_import_services.dart';
import '../import/url_import_service.dart';
import '../services/platform/backup_file_picker.dart';
import '../services/providers.dart';

/// Infrastructure singletons created during bootstrap and injected via
/// [ProviderScope.overrides]; tests override them with in-memory fakes.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) =>
      throw UnimplementedError('libraryRepositoryProvider must be overridden'),
);

final mediaStoreProvider = Provider<MediaStore>(
  (ref) => throw UnimplementedError('mediaStoreProvider must be overridden'),
);

/// Import services, derived from the infrastructure above.
final importCoordinatorProvider = Provider<ImportCoordinator>(
  (ref) => ImportCoordinator(
    repository: ref.watch(libraryRepositoryProvider),
    mediaStore: ref.watch(mediaStoreProvider),
  ),
);

final urlImportServiceProvider = Provider<UrlImportService>(
  (ref) => UrlImportService(ref.watch(importCoordinatorProvider)),
);

final clipboardImportServiceProvider = Provider<ClipboardImportService>(
  (ref) => ClipboardImportService(
    ref.watch(importCoordinatorProvider),
    ref.watch(clipboardServiceProvider),
  ),
);

final shareImportServiceProvider = Provider<ShareImportService>(
  (ref) => ShareImportService(ref.watch(importCoordinatorProvider)),
);

/// Scratch directory for backup archives and restore staging.
final backupWorkDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
    'backupWorkDirectoryProvider must be overridden',
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    repository: ref.watch(libraryRepositoryProvider),
    mediaStore: ref.watch(mediaStoreProvider),
    workDirectory: ref.watch(backupWorkDirectoryProvider),
  ),
);

final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => const FileSelectorBackupFilePicker(),
);
