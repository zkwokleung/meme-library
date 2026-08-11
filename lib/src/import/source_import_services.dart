import 'dart:io';

import 'package:flutter/services.dart';

import '../data/image_validator.dart';
import '../domain/meme.dart';
import '../services/platform/clipboard_service.dart';
import '../services/platform/gallery_picker.dart';
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
            // No sourceRef: the staged file name is a random UUID from
            // the native side, not meaningful provenance.
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

/// Imports images chosen from the photo gallery and removes the picker's
/// temporary copies.
///
/// Reads one file at a time rather than going through
/// [ImportCoordinator.importAll]: that takes a `List<Uint8List>`, so a
/// twenty-photo selection at the validator's 25 MiB cap would hold half a
/// gigabyte resident at once.
class GalleryImportService {
  GalleryImportService(this._coordinator, this._heic);

  final ImportCoordinator _coordinator;
  final HeicTranscoder _heic;

  /// Bytes needed to recognise an ISO-BMFF `ftyp` box and its major brand.
  static const _headerBytes = 32;

  Future<List<ImportOutcome>> importPicked(
    List<PickedGalleryImage> picked, {
    ImportProgress? onProgress,
  }) async {
    final outcomes = <ImportOutcome>[];
    for (var i = 0; i < picked.length; i++) {
      final file = File(picked[i].path);
      try {
        // Sniff the header, never the extension: the picker derives the
        // extension from a MIME type that can be wrong. Reading the whole
        // file just to discover it needs transcoding would defeat the
        // point of checking at all.
        final header = await _readHeader(file);
        final bytes = ImageValidator.isHeif(header)
            ? await _heic.transcodeToJpeg(file.path)
            : await file.readAsBytes();
        outcomes.add(
          bytes == null
              ? const ImportFailure(
                  ImportFailureReason.unsupportedFormat,
                  'This photo could not be converted to a supported format.',
                )
              : await _coordinator.importBytes(
                  bytes,
                  sourceKind: MemeSourceKind.gallery,
                  // The gallery name is real provenance, unlike the
                  // native UUID a share is staged under, and it feeds the
                  // search index.
                  sourceRef: picked[i].displayName,
                ),
        );
      } on FileSystemException {
        outcomes.add(
          const ImportFailure(
            ImportFailureReason.unknown,
            'This photo could not be read.',
          ),
        );
      } on PlatformException {
        outcomes.add(
          const ImportFailure(
            ImportFailureReason.unsupportedFormat,
            'This photo could not be converted to a supported format.',
          ),
        );
      } finally {
        // The picker's copy belongs to us; always clean it up.
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Temp files are also purged by the OS eventually.
        }
      }
      onProgress?.call(i + 1, picked.length);
    }
    return outcomes;
  }

  static Future<Uint8List> _readHeader(File file) async {
    final handle = await file.open();
    try {
      return await handle.read(_headerBytes);
    } finally {
      await handle.close();
    }
  }
}
