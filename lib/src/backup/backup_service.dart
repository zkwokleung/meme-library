import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/image_validator.dart';
import '../data/library_repository.dart';
import '../data/media_store.dart';
import '../domain/library_query.dart';
import '../domain/meme.dart';

enum BackupErrorReason {
  unreadableArchive,
  malformedManifest,
  unsupportedVersion,
  missingMedia,
  checksumMismatch,
  applyFailed,
}

class BackupException implements Exception {
  const BackupException(this.reason, this.message);

  final BackupErrorReason reason;

  /// Human-readable, actionable description.
  final String message;

  @override
  String toString() => 'BackupException($reason): $message';
}

class RestoreSummary {
  const RestoreSummary({required this.memeCount, required this.tagCount});

  final int memeCount;
  final int tagCount;
}

/// Progress callback for export/restore: [done] of [total] steps.
typedef BackupProgress = void Function(int done, int total);

/// Versioned, integrity-checked library backup.
///
/// The archive layout (format version 1):
/// ```
/// manifest.json          — version, creation time, full meme metadata
/// media/originals/…      — original images, hash-keyed file names
/// media/thumbs/…         — thumbnails (optional; regenerated if absent)
/// ```
/// Each meme's SHA-256 in the manifest doubles as the checksum of its
/// original file.
class BackupService {
  BackupService({
    required LibraryRepository repository,
    required MediaStore mediaStore,
    required Directory workDirectory,
  }) : _repository = repository,
       _media = mediaStore,
       _work = workDirectory;

  static const formatVersion = 1;

  final LibraryRepository _repository;
  final MediaStore _media;

  /// Scratch space for archives and restore staging.
  final Directory _work;

  /// Test hook: runs after validation and staging, before the library is
  /// replaced. Lets tests simulate an interruption at the point of no
  /// return.
  @visibleForTesting
  Future<void> Function()? debugBeforeApply;

  // -- Export ------------------------------------------------------------

  /// Streams the complete library into a ZIP file and returns it.
  ///
  /// Files are added one at a time from disk, so memory stays flat no
  /// matter how large the library is.
  Future<File> exportArchive({BackupProgress? onProgress}) async {
    final memes = await _allMemes();
    await _work.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final zipFile = File(p.join(_work.path, 'meme-library-$stamp.zip'));

    final manifest = {
      'version': formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'memeCount': memes.length,
      'memes': [for (final meme in memes) meme.toJson()],
    };

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    final manifestFile = File(p.join(_work.path, 'manifest.json'));
    try {
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
      await encoder.addFile(manifestFile, 'manifest.json');

      var done = 0;
      for (final meme in memes) {
        final original = _media.resolve(meme.relativePath);
        if (!await original.exists()) {
          throw BackupException(
            BackupErrorReason.missingMedia,
            'The image for "${meme.title ?? meme.id}" is missing on disk.',
          );
        }
        await encoder.addFile(original, 'media/${meme.relativePath}');
        final thumb = _media.resolve(meme.thumbnailPath);
        if (await thumb.exists()) {
          await encoder.addFile(thumb, 'media/${meme.thumbnailPath}');
        }
        onProgress?.call(++done, memes.length);
      }
    } catch (e) {
      await encoder.close();
      if (await zipFile.exists()) await zipFile.delete();
      rethrow;
    } finally {
      // The manifest holds the full plaintext metadata of the library;
      // never leave it behind in the work directory.
      if (await manifestFile.exists()) await manifestFile.delete();
    }
    await encoder.close();
    return zipFile;
  }

  // -- Restore -----------------------------------------------------------

  /// Replaces the library with the archive contents, transactionally.
  ///
  /// The archive is fully validated and staged before anything is
  /// touched; failures at any point leave the current library unchanged.
  /// Restoring the same archive twice is idempotent.
  Future<RestoreSummary> restoreArchive(
    File zipFile, {
    BackupProgress? onProgress,
  }) async {
    final staging = Directory(
      p.join(_work.path, 'restore-${const Uuid().v4()}'),
    );
    await staging.create(recursive: true);

    try {
      final (manifest, memes) = await _readManifest(zipFile);
      await _stageAndVerify(zipFile, memes, staging, onProgress);
      await debugBeforeApply?.call();
      return await _apply(memes, staging);
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<(Map<String, Object?>, List<Meme>)> _readManifest(File zipFile) async {
    // The zip decoder is lenient with garbage input, so check the
    // signature explicitly before parsing.
    final header = await zipFile
        .openRead(0, 2)
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    if (header.length < 2 || header[0] != 0x50 || header[1] != 0x4B) {
      throw const BackupException(
        BackupErrorReason.unreadableArchive,
        'This file is not a readable backup archive.',
      );
    }

    InputFileStream? input;
    try {
      final Archive archive;
      try {
        input = InputFileStream(zipFile.path);
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BackupException(
          BackupErrorReason.unreadableArchive,
          'This file is not a readable backup archive.',
        );
      }
      return _parseManifest(archive);
    } finally {
      await input?.close();
    }
  }

  (Map<String, Object?>, List<Meme>) _parseManifest(Archive archive) {
    final entry = archive.find('manifest.json');
    if (entry == null) {
      throw const BackupException(
        BackupErrorReason.malformedManifest,
        'The archive has no manifest.',
      );
    }

    final Map<String, Object?> manifest;
    final List<Meme> memes;
    try {
      manifest =
          jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, Object?>;
    } catch (_) {
      throw const BackupException(
        BackupErrorReason.malformedManifest,
        'The backup manifest is damaged.',
      );
    }

    final version = manifest['version'];
    if (version is! int || version <= 0) {
      throw const BackupException(
        BackupErrorReason.malformedManifest,
        'The backup manifest has no valid version.',
      );
    }
    if (version > formatVersion) {
      throw BackupException(
        BackupErrorReason.unsupportedVersion,
        'This backup was created by a newer version of Meme Library. '
        'Update the app, then try again.',
      );
    }

    try {
      memes = [
        for (final raw in manifest['memes']! as List<Object?>)
          Meme.fromJson(raw! as Map<String, Object?>),
      ];
    } catch (_) {
      throw const BackupException(
        BackupErrorReason.malformedManifest,
        'The backup manifest is damaged.',
      );
    }
    // Reject path traversal (zip-slip): manifest paths are attacker
    // input and are later joined onto staging and the live media root.
    for (final meme in memes) {
      _requireSafeRelativePath(meme.relativePath, 'originals');
      _requireSafeRelativePath(meme.thumbnailPath, 'thumbs');
    }
    return (manifest, memes);
  }

  /// Throws unless [path] is a plain relative POSIX path rooted in
  /// [requiredRoot] with no traversal segments, drive letters, or
  /// backslashes.
  static void _requireSafeRelativePath(String path, String requiredRoot) {
    final parts = p.posix.split(p.posix.normalize(path));
    final unsafe =
        path.contains('\\') ||
        path.contains(':') ||
        p.isAbsolute(path) ||
        p.posix.isAbsolute(path) ||
        parts.length < 2 ||
        parts.first != requiredRoot ||
        parts.any((part) => part == '..' || part == '.' || part.isEmpty);
    if (unsafe) {
      throw const BackupException(
        BackupErrorReason.malformedManifest,
        'The backup manifest contains an invalid media path.',
      );
    }
  }

  /// Extracts every referenced media file into [staging], verifying the
  /// SHA-256 of each original against the manifest.
  Future<void> _stageAndVerify(
    File zipFile,
    List<Meme> memes,
    Directory staging,
    BackupProgress? onProgress,
  ) async {
    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var done = 0;
      for (final meme in memes) {
        final entry = archive.find('media/${meme.relativePath}');
        if (entry == null) {
          throw BackupException(
            BackupErrorReason.missingMedia,
            'The archive is missing the image for '
            '"${meme.title ?? meme.id}".',
          );
        }
        final target = File(p.join(staging.path, meme.relativePath));
        await target.parent.create(recursive: true);
        await _extractEntry(entry, target);

        final digest = await sha256.bind(target.openRead()).first;
        if (digest.toString() != meme.sha256) {
          throw BackupException(
            BackupErrorReason.checksumMismatch,
            'The image for "${meme.title ?? meme.id}" is corrupted in '
            'this backup.',
          );
        }

        // Thumbnails are best-effort: restore if present, else rebuild.
        final thumbEntry = archive.find('media/${meme.thumbnailPath}');
        final thumbTarget = File(p.join(staging.path, meme.thumbnailPath));
        await thumbTarget.parent.create(recursive: true);
        if (thumbEntry != null) {
          await _extractEntry(thumbEntry, thumbTarget);
        } else {
          await _regenerateThumbnail(target, thumbTarget);
        }
        onProgress?.call(++done, memes.length);
      }
    } finally {
      await input.close();
    }
  }

  /// Streams a zip entry to [target], closing the sink on failure so the
  /// staging directory can always be deleted afterwards.
  static Future<void> _extractEntry(ArchiveFile entry, File target) async {
    final out = OutputFileStream(target.path);
    try {
      entry.writeContent(out);
    } finally {
      await out.close();
    }
  }

  /// Rebuilds a thumbnail directly into staging. Must never touch the
  /// live media store: staging runs before the point of no return.
  Future<void> _regenerateThumbnail(File original, File thumbTarget) async {
    try {
      final validated = const ImageValidator().validate(
        await original.readAsBytes(),
      );
      await thumbTarget.writeAsBytes(
        _media.encodeThumbnail(validated).bytes,
        flush: true,
      );
    } catch (_) {
      // A meme without a thumbnail still renders from the original.
    }
  }

  /// Moves staged media into the live store, then replaces the database
  /// contents. DB failure leaves the previous records in place; stray
  /// files are swept afterwards either way.
  Future<RestoreSummary> _apply(List<Meme> memes, Directory staging) async {
    for (final meme in memes) {
      await _moveStaged(staging, meme.relativePath);
      await _moveStaged(staging, meme.thumbnailPath, optional: true);
    }

    try {
      await _repository.replaceAll(memes);
    } catch (e) {
      // Remove only the files this restore moved in and that no existing
      // record references. A full reconcile here could purge unrelated
      // records whose files were already broken before the restore.
      final referenced = await _repository.referencedMediaPaths();
      for (final meme in memes) {
        for (final path in [meme.relativePath, meme.thumbnailPath]) {
          if (!referenced.contains(path)) {
            await _media.delete(path, path);
          }
        }
      }
      throw BackupException(
        BackupErrorReason.applyFailed,
        'The library could not be replaced ($e). '
        'Your current memes were not changed.',
      );
    }

    await _repository.reconcile();
    final tagIds = <String>{
      for (final meme in memes)
        for (final tag in meme.tags) tag.id,
    };
    return RestoreSummary(memeCount: memes.length, tagCount: tagIds.length);
  }

  Future<void> _moveStaged(
    Directory staging,
    String relativePath, {
    bool optional = false,
  }) async {
    final source = File(p.join(staging.path, relativePath));
    if (!await source.exists()) {
      if (optional) return;
      throw BackupException(
        BackupErrorReason.missingMedia,
        'Staged file $relativePath disappeared during restore.',
      );
    }
    final target = _media.resolve(relativePath);
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      // Hash-keyed names: same name means same content.
      await source.delete();
      return;
    }
    await source.rename(target.path);
  }

  Future<List<Meme>> _allMemes() async {
    final memes = <Meme>[];
    var offset = 0;
    while (true) {
      final page = await _repository.query(
        LibraryQuery(limit: 500, offset: offset),
      );
      memes.addAll(page.items);
      offset += page.items.length;
      if (page.items.isEmpty || offset >= page.totalCount) break;
    }
    return memes;
  }
}
