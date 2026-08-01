import 'dart:io';

import '../domain/meme.dart';
import '../services/platform/clipboard_service.dart';
import '../services/platform/incoming_share_service.dart';
import 'import_coordinator.dart';

/// Imports the current clipboard image, if any.
class ClipboardImportService {
  ClipboardImportService(this._coordinator, this._clipboard);

  final ImportCoordinator _coordinator;
  final ClipboardService _clipboard;

  Future<ImportOutcome> importFromClipboard() async {
    final ClipboardImage? image;
    try {
      image = await _clipboard.readImage();
    } catch (_) {
      return const ImportFailure(
        ImportFailureReason.unknown,
        'The clipboard could not be read.',
      );
    }
    if (image == null || image.bytes.isEmpty) {
      return const ImportFailure(
        ImportFailureReason.emptySource,
        'Copy an image first, then try again.',
      );
    }
    return _coordinator.importBytes(
      image.bytes,
      sourceKind: MemeSourceKind.clipboard,
      sourceRef: image.suggestedName,
    );
  }
}

/// Imports files shared into the app and removes the staged copies.
class ShareImportService {
  ShareImportService(this._coordinator);

  final ImportCoordinator _coordinator;

  Future<List<ImportOutcome>> importShared(
    List<IncomingSharedFile> files, {
    ImportProgress? onProgress,
  }) async {
    final outcomes = <ImportOutcome>[];
    for (var i = 0; i < files.length; i++) {
      final file = File(files[i].path);
      try {
        final bytes = await file.readAsBytes();
        outcomes.add(
          await _coordinator.importBytes(
            bytes,
            sourceKind: MemeSourceKind.share,
            sourceRef: file.uri.pathSegments.isNotEmpty
                ? file.uri.pathSegments.last
                : null,
          ),
        );
      } on FileSystemException {
        outcomes.add(
          const ImportFailure(
            ImportFailureReason.unknown,
            'The shared file could not be read.',
          ),
        );
      } finally {
        // The staged copy belongs to us; always clean it up.
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Temp files are also purged by the OS eventually.
        }
      }
      onProgress?.call(i + 1, files.length);
    }
    return outcomes;
  }
}
