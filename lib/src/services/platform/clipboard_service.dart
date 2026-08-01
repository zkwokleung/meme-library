import 'dart:typed_data';

/// An image read from or written to the system clipboard.
class ClipboardImage {
  const ClipboardImage({required this.bytes, this.suggestedName});

  /// Encoded image bytes exactly as provided by the platform.
  final Uint8List bytes;

  /// Optional file name hint provided by the source, if any.
  final String? suggestedName;
}

/// Boundary for platform clipboard access.
///
/// Implementations handle platform privacy prompts and content-URI
/// resolution; callers only see decoded-agnostic image bytes.
abstract interface class ClipboardService {
  /// Reads an image from the clipboard, or `null` when the clipboard is
  /// empty or holds no supported image payload.
  Future<ClipboardImage?> readImage();

  /// Places [image] on the clipboard so other apps can paste it.
  ///
  /// Returns `false` when the platform cannot host image data on the
  /// clipboard, letting callers fall back to the share sheet.
  Future<bool> writeImage(ClipboardImage image);
}
