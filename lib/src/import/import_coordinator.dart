import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../data/image_validator.dart';
import '../data/library_repository.dart';
import '../data/media_store.dart';
import '../domain/meme.dart';

/// Why an import failed, mapped to user-actionable categories.
enum ImportFailureReason {
  emptySource,
  unsupportedFormat,
  animated,
  tooLarge,
  corrupt,
  network,
  storage,
  unknown,
}

/// Result of importing a single item.
sealed class ImportOutcome {
  const ImportOutcome();
}

class ImportSuccess extends ImportOutcome {
  const ImportSuccess(this.meme, {required this.wasDuplicate});

  final Meme meme;

  /// True when the content already existed and [meme] is the existing item.
  final bool wasDuplicate;
}

class ImportFailure extends ImportOutcome {
  const ImportFailure(this.reason, this.message);

  final ImportFailureReason reason;

  /// Human-readable, actionable description.
  final String message;
}

/// Progress callback: [done] of [total] items finished.
typedef ImportProgress = void Function(int done, int total);

/// The single import path used by every source (clipboard, URL, share).
///
/// Coordinates validation, hashing, duplicate resolution, media storage,
/// and the repository write. Failures never leave staged artifacts: the
/// media store cleans its own staging, and the repository removes stored
/// files when the database write fails.
class ImportCoordinator {
  ImportCoordinator({
    required LibraryRepository repository,
    required MediaStore mediaStore,
    ImageValidator validator = const ImageValidator(),
    DateTime Function()? clock,
  }) : _repository = repository,
       _media = mediaStore,
       _validator = validator,
       _clock = clock ?? DateTime.now;

  final LibraryRepository _repository;
  final MediaStore _media;
  final ImageValidator _validator;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  /// Imports one image. Duplicate content resolves to the existing meme.
  Future<ImportOutcome> importBytes(
    Uint8List bytes, {
    required MemeSourceKind sourceKind,
    String? sourceRef,
  }) async {
    final ValidatedImage image;
    try {
      image = _validator.validate(bytes);
    } on ImageValidationException catch (e) {
      return ImportFailure(_mapRejection(e.rejection), _describeRejection(e));
    }

    final hash = MediaStore.hashBytes(image.bytes);
    final existing = await _repository.memeBySha256(hash);
    if (existing != null) {
      return ImportSuccess(existing, wasDuplicate: true);
    }

    final StoredMedia stored;
    try {
      stored = await _media.store(image, knownSha256: hash);
    } on MediaStoreException catch (e) {
      return ImportFailure(
        ImportFailureReason.storage,
        'The image could not be saved to storage. ${e.message}',
      );
    }

    final now = _clock().toUtc();
    final meme = Meme(
      id: _uuid.v4(),
      sha256: hash,
      mimeType: image.mimeType,
      width: image.width,
      height: image.height,
      sizeBytes: image.sizeBytes,
      relativePath: stored.relativePath,
      thumbnailPath: stored.thumbnailPath,
      sourceKind: sourceKind,
      sourceRef: sourceRef,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final saved = await _repository.insertMeme(meme);
      return ImportSuccess(saved, wasDuplicate: false);
    } on DuplicateMemeException catch (e) {
      // Lost a race with a concurrent import of the same content. Files
      // are hash-keyed, so they are shared with the winner; nothing to
      // clean up.
      return ImportSuccess(e.existing, wasDuplicate: true);
    } catch (e) {
      // insertMeme already removed the stored files.
      return ImportFailure(
        ImportFailureReason.storage,
        'The image could not be added to the library.',
      );
    }
  }

  /// Imports several items sequentially, reporting progress after each.
  Future<List<ImportOutcome>> importAll(
    List<Uint8List> items, {
    required MemeSourceKind sourceKind,
    List<String?>? sourceRefs,
    ImportProgress? onProgress,
  }) async {
    if (sourceRefs != null && sourceRefs.length != items.length) {
      throw ArgumentError.value(
        sourceRefs,
        'sourceRefs',
        'must match items in length',
      );
    }
    final outcomes = <ImportOutcome>[];
    for (var i = 0; i < items.length; i++) {
      outcomes.add(
        await importBytes(
          items[i],
          sourceKind: sourceKind,
          sourceRef: sourceRefs?[i],
        ),
      );
      onProgress?.call(i + 1, items.length);
    }
    return outcomes;
  }

  static ImportFailureReason _mapRejection(ImageRejection rejection) =>
      switch (rejection) {
        ImageRejection.empty => ImportFailureReason.emptySource,
        ImageRejection.tooLarge ||
        ImageRejection.tooManyPixels => ImportFailureReason.tooLarge,
        ImageRejection.unsupportedFormat =>
          ImportFailureReason.unsupportedFormat,
        ImageRejection.animated => ImportFailureReason.animated,
        ImageRejection.corrupt => ImportFailureReason.corrupt,
      };

  static String _describeRejection(ImageValidationException e) =>
      switch (e.rejection) {
        ImageRejection.empty => 'There was no image data to import.',
        ImageRejection.tooLarge => 'The image is too large to import.',
        ImageRejection.tooManyPixels => 'The image is too large to import.',
        ImageRejection.unsupportedFormat =>
          'Only PNG, JPEG, and WebP images are supported.',
        ImageRejection.animated => 'Animated images are not supported.',
        ImageRejection.corrupt => 'The image data is damaged or incomplete.',
      };
}
