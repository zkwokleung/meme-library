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

/// An encoded thumbnail plus the extension that matches its format.
class EncodedThumbnail {
  const EncodedThumbnail({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// `png`, `jpg`, or `gif` (animated), without a dot.
  final String extension;
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

  /// Animated thumbnails sample the source down to at most this many
  /// frames, keeping grid playback memory bounded.
  static const maxThumbnailFrames = 48;

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
    final thumb = encodeThumbnail(image);
    final thumbName = '${hash}_t.${thumb.extension}';

    final stagedOriginal = File(p.join(_staging.path, '$originalName.tmp'));
    final stagedThumb = File(p.join(_staging.path, '$thumbName.tmp'));
    final finalOriginal = File(p.join(_originals.path, originalName));
    final finalThumb = File(p.join(_thumbs.path, thumbName));

    try {
      await stagedOriginal.writeAsBytes(image.bytes, flush: true);
      await stagedThumb.writeAsBytes(thumb.bytes, flush: true);

      // Hash-keyed names mean an existing destination holds identical
      // content (e.g. a concurrent import of the same image); it must
      // survive our rollback.
      final originalExisted = await finalOriginal.exists();
      await stagedOriginal.rename(finalOriginal.path);
      try {
        await stagedThumb.rename(finalThumb.path);
      } catch (e) {
        if (!originalExisted) {
          await _deleteIfExists(finalOriginal);
        }
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

  /// Encodes a thumbnail for [image] without writing to the store.
  ///
  /// The output format is a pure function of the source bytes so backup
  /// restore can regenerate a thumbnail that matches its manifest name:
  /// animated sources become small animated GIFs (grid tiles play them),
  /// static sources with transparency (including GIF palette
  /// transparency) become PNG, everything else JPEG.
  EncodedThumbnail encodeThumbnail(ValidatedImage image) {
    final decoded = img.decodeImage(image.bytes);
    if (decoded == null) {
      throw const MediaStoreException('Image could not be decoded');
    }

    if (image.isAnimated && decoded.numFrames > 1) {
      return EncodedThumbnail(
        bytes: _encodeAnimatedGifThumbnail(decoded),
        extension: 'gif',
      );
    }

    final resized = _resizeFrame(decoded);
    final transparent = image.hasAlpha || image.fileExtension == 'gif';
    return EncodedThumbnail(
      bytes: transparent
          ? img.encodePng(resized)
          : img.encodeJpg(resized, quality: 82),
      extension: transparent ? 'png' : 'jpg',
    );
  }

  /// Downscaled animated GIF preserving timing and loop count, sampled
  /// to at most [maxThumbnailFrames] frames.
  Uint8List _encodeAnimatedGifThumbnail(img.Image decoded) {
    final sourceFrames = decoded.frames;
    final keepEvery = sourceFrames.length <= maxThumbnailFrames
        ? 1
        : sourceFrames.length / maxThumbnailFrames;

    img.Image? animation;
    var nextKept = 0.0;
    var carriedDuration = 0;
    for (var i = 0; i < sourceFrames.length; i++) {
      final frame = sourceFrames[i];
      if (i < nextKept.floor()) {
        // Skipped frame: keep the wall-clock duration on the previous
        // kept frame so playback speed is preserved.
        carriedDuration += frame.frameDuration;
        continue;
      }
      nextKept += keepEvery;

      // Clone as a single frame first: copyResize on an animated image
      // would resize the entire frame chain per call.
      var single = img.Image.from(frame, noAnimation: true);
      single = _resizeFrame(single);
      single.frameDuration = frame.frameDuration + carriedDuration;
      carriedDuration = 0;

      if (animation == null) {
        animation = single;
        animation.loopCount = decoded.loopCount;
      } else {
        animation.addFrame(single);
      }
    }

    return img.encodeGif(animation!, repeat: decoded.loopCount);
  }

  img.Image _resizeFrame(img.Image frame) {
    final longest = frame.width > frame.height ? frame.width : frame.height;
    if (longest <= _thumbnailMax) return frame;
    return img.copyResize(
      frame,
      width: frame.width >= frame.height ? _thumbnailMax : null,
      height: frame.height > frame.width ? _thumbnailMax : null,
      interpolation: img.Interpolation.average,
    );
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
