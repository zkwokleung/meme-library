import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'image_validator.dart';

class MediaStoreException implements Exception {
  const MediaStoreException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'MediaStoreException: $message';
}

/// Result of persisting an image: media-root-relative paths only.
class StoredMedia {
  const StoredMedia({
    required this.sha256,
    required this.relativePath,
    required this.thumbnailPath,
  });

  final String sha256;
  final String relativePath;
  final String thumbnailPath;
}

/// App-owned storage for original images and generated thumbnails.
///
/// Files are keyed by content hash (`originals/<sha256>.<ext>`), written to
/// a staging directory first, and moved into place with atomic renames so
/// failures never leave partial files in the library.
class MediaStore {
  MediaStore(this.root, {int thumbnailMaxDimension = defaultThumbnailSize})
    : _thumbnailMax = thumbnailMaxDimension;

  static const defaultThumbnailSize = 400;

  final Directory root;
  final int _thumbnailMax;

  Directory get _originals => Directory(p.join(root.path, 'originals'));
  Directory get _thumbs => Directory(p.join(root.path, 'thumbs'));
  Directory get _staging => Directory(p.join(root.path, 'staging'));

  Future<void> init() async {
    await _originals.create(recursive: true);
    await _thumbs.create(recursive: true);
    await _staging.create(recursive: true);
  }

  /// Computes the content hash used as the storage key.
  static String hashBytes(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Resolves a media-root-relative path to a file.
  File resolve(String relativePath) => File(p.join(root.path, relativePath));

  Future<bool> exists(String relativePath) => resolve(relativePath).exists();

  /// Stores a validated image and its thumbnail atomically.
  ///
  /// Both files are fully written to staging before either is moved into
  /// the library; any failure removes all staged and moved artifacts.
  Future<StoredMedia> store(ValidatedImage image, {String? knownSha256}) async {
    await init();
    final hash = knownSha256 ?? hashBytes(image.bytes);
    final originalName = '$hash.${image.fileExtension}';
    final thumbExtension = image.hasAlpha ? 'png' : 'jpg';
    final thumbName = '${hash}_t.$thumbExtension';

    final stagedOriginal = File(p.join(_staging.path, '$originalName.tmp'));
    final stagedThumb = File(p.join(_staging.path, '$thumbName.tmp'));
    final finalOriginal = File(p.join(_originals.path, originalName));
    final finalThumb = File(p.join(_thumbs.path, thumbName));

    try {
      await stagedOriginal.writeAsBytes(image.bytes, flush: true);
      await stagedThumb.writeAsBytes(_encodeThumbnail(image), flush: true);

      await stagedOriginal.rename(finalOriginal.path);
      try {
        await stagedThumb.rename(finalThumb.path);
      } catch (e) {
        await _deleteIfExists(finalOriginal);
        rethrow;
      }
    } catch (e) {
      await _deleteIfExists(stagedOriginal);
      await _deleteIfExists(stagedThumb);
      if (e is MediaStoreException) rethrow;
      throw MediaStoreException('Failed to store image $hash', e);
    }

    return StoredMedia(
      sha256: hash,
      relativePath: p.posix.join('originals', originalName),
      thumbnailPath: p.posix.join('thumbs', thumbName),
    );
  }

  Uint8List _encodeThumbnail(ValidatedImage image) {
    final decoded = img.decodeImage(image.bytes);
    if (decoded == null) {
      throw const MediaStoreException('Image could not be decoded');
    }
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest <= _thumbnailMax
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _thumbnailMax : null,
            height: decoded.height > decoded.width ? _thumbnailMax : null,
            interpolation: img.Interpolation.average,
          );
    return image.hasAlpha
        ? img.encodePng(resized)
        : img.encodeJpg(resized, quality: 82);
  }

  /// Deletes the stored files for a meme. Missing files are ignored.
  Future<void> delete(String relativePath, String thumbnailPath) async {
    await _deleteIfExists(resolve(relativePath));
    await _deleteIfExists(resolve(thumbnailPath));
  }

  /// Removes any leftover staging files (e.g. after a crash).
  Future<void> clearStaging() async {
    if (await _staging.exists()) {
      await for (final entry in _staging.list()) {
        await entry.delete(recursive: true);
      }
    }
  }

  /// Lists all stored files as media-root-relative POSIX paths.
  Future<Set<String>> listManagedFiles() async {
    final result = <String>{};
    for (final dir in [_originals, _thumbs]) {
      if (!await dir.exists()) continue;
      await for (final entry in dir.list()) {
        if (entry is File) {
          result.add(
            p.posix.joinAll(p.split(p.relative(entry.path, from: root.path))),
          );
        }
      }
    }
    return result;
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort; orphans are removed by reconciliation.
    }
  }
}
