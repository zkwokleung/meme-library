import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// An image the user chose in the system photo picker.
class PickedGalleryImage {
  const PickedGalleryImage({required this.path, this.displayName});

  /// Absolute path of a temporary copy owned by this app. The caller is
  /// responsible for deleting it.
  final String path;

  /// The gallery's display name, when it is meaningful provenance.
  final String? displayName;
}

/// Boundary for choosing images from the system photo gallery.
abstract interface class GalleryPicker {
  /// Returns the chosen images, or an empty list when the user cancels.
  ///
  /// Unlike `BackupFilePicker`, cancellation is an empty list rather than
  /// `null`: a multi-select picker cannot distinguish "cancelled" from
  /// "picked nothing", and callers treat both the same way.
  Future<List<PickedGalleryImage>> pickImages();
}

/// Android photo picker (`ACTION_PICK_IMAGES`) via `image_picker`.
///
/// Needs no runtime permission. With no `maxWidth`/`maxHeight`/
/// `imageQuality`, the plugin's `ImageResizer` short-circuits and returns
/// the original file byte-for-byte, so animated GIF, animated WebP, and
/// APNG all survive the trip.
///
/// iOS deliberately does not use this: `image_picker_ios` re-encodes every
/// result through `UIImage`, which cannot be turned off. It goes through
/// `ChannelGalleryPicker` and `PHPickerViewController` instead.
class ImagePickerGalleryPicker implements GalleryPicker {
  const ImagePickerGalleryPicker();

  @override
  Future<List<PickedGalleryImage>> pickImages() async {
    final files = await ImagePicker().pickMultiImage(
      requestFullMetadata: false,
    );
    return [
      for (final file in files)
        PickedGalleryImage(
          path: file.path,
          displayName: meaningfulDisplayName(file.name),
        ),
    ];
  }

  /// Drops the picker's own scratch names.
  ///
  /// `image_picker` copies each asset to `image_picker_<uuid>.jpg`, which
  /// is not provenance anyone would search the library for.
  static String? meaningfulDisplayName(String? name) {
    if (name == null || name.isEmpty) return null;
    return name.startsWith('image_picker_') ? null : name;
  }
}

/// Boundary for converting HEIC/HEIF, which none of the bundled decoders
/// can read, into bytes the import pipeline accepts.
abstract interface class HeicTranscoder {
  /// Returns JPEG bytes for the HEIC/HEIF file at [path], or `null` when
  /// the platform cannot decode it.
  Future<Uint8List?> transcodeToJpeg(String path);
}
