import 'dart:isolate';
import 'dart:typed_data';

import 'image_validator.dart';
import 'media_store.dart';

/// Validated metadata plus the content hash, in a form that can cross an
/// isolate boundary.
///
/// The original bytes are deliberately not carried back: the caller
/// already holds them, and echoing up to 25 MiB would double the copy cost
/// for nothing. Use [toValidatedImage] to rejoin the two.
class ProbedImage {
  const ProbedImage({
    required this.sha256,
    required this.mimeType,
    required this.fileExtension,
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.frameCount,
  });

  final String sha256;
  final String mimeType;
  final String fileExtension;
  final int width;
  final int height;
  final bool hasAlpha;
  final int frameCount;

  bool get isAnimated => frameCount > 1;

  /// Rejoins this metadata with the bytes it was derived from.
  ValidatedImage toValidatedImage(Uint8List bytes) => ValidatedImage(
    bytes: bytes,
    mimeType: mimeType,
    fileExtension: fileExtension,
    width: width,
    height: height,
    hasAlpha: hasAlpha,
    frameCount: frameCount,
  );
}

/// Validates [bytes] and hashes them in one pass.
///
/// Top-level and free of `dart:io`, Drift, and Flutter bindings so it can
/// run on a background isolate. Throws [ImageValidationException], which
/// is an enum plus a String and so survives the isolate boundary intact.
ProbedImage probeImageSync(
  Uint8List bytes, {
  ImageValidator validator = const ImageValidator(),
}) {
  final image = validator.validate(bytes);
  return ProbedImage(
    sha256: MediaStore.hashBytes(image.bytes),
    mimeType: image.mimeType,
    fileExtension: image.fileExtension,
    width: image.width,
    height: image.height,
    hasAlpha: image.hasAlpha,
    frameCount: image.frameCount,
  );
}

/// The CPU-bound half of the import pipeline: decode, hash, and thumbnail.
///
/// Split behind an interface purely so tests can run the work inline —
/// a real isolate does not complete deterministically inside
/// `flutter_test`'s fake-async zone.
abstract interface class ImagePipeline {
  /// Validates and hashes [bytes].
  ///
  /// Throws [ImageValidationException] when the image is not acceptable.
  Future<ProbedImage> probe(
    Uint8List bytes, {
    ImageValidator validator = const ImageValidator(),
  });

  /// Encodes a thumbnail whose longest edge is at most [maxDimension].
  ///
  /// Throws [MediaStoreException] when the image cannot be decoded.
  Future<EncodedThumbnail> thumbnail(
    ValidatedImage image, {
    required int maxDimension,
  });
}

/// Production pipeline: keeps decoding, resizing, and hashing off the UI
/// isolate so a multi-image import does not freeze the app.
///
/// Probing and thumbnailing are separate isolate calls on purpose. Fusing
/// them would push the duplicate check after thumbnail generation, wasting
/// a full decode (and, for animations, a full GIF re-encode) every time a
/// user re-picks an image the library already holds.
class IsolateImagePipeline implements ImagePipeline {
  const IsolateImagePipeline();

  @override
  Future<ProbedImage> probe(
    Uint8List bytes, {
    ImageValidator validator = const ImageValidator(),
  }) => Isolate.run(() => probeImageSync(bytes, validator: validator));

  @override
  Future<EncodedThumbnail> thumbnail(
    ValidatedImage image, {
    required int maxDimension,
  }) =>
      Isolate.run(() => encodeThumbnailSync(image, maxDimension: maxDimension));
}

/// Runs the same work on the calling isolate.
///
/// Widget tests need this: `Isolate.run` completes through a `ReceivePort`
/// that `flutter_test`'s fake-async zone cannot reliably pump.
class InlineImagePipeline implements ImagePipeline {
  const InlineImagePipeline();

  @override
  Future<ProbedImage> probe(
    Uint8List bytes, {
    ImageValidator validator = const ImageValidator(),
  }) async => probeImageSync(bytes, validator: validator);

  @override
  Future<EncodedThumbnail> thumbnail(
    ValidatedImage image, {
    required int maxDimension,
  }) async => encodeThumbnailSync(image, maxDimension: maxDimension);
}
