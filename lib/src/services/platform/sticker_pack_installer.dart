import 'dart:typed_data';

/// Outcome of handing a pack to WhatsApp. Android reports `added` or
/// `cancelled` from the activity round trip; iOS can only report `started`
/// because the pasteboard handoff never comes back.
enum InstallStickerPackResult {
  added,
  started,
  cancelled,
  whatsappNotInstalled,
  failed,
}

/// A fully encoded pack, ready for the iOS pasteboard handoff.
class StickerPackPayload {
  const StickerPackPayload({
    required this.identifier,
    required this.name,
    required this.publisher,
    required this.trayPng,
    required this.stickers,
  });

  final String identifier;
  final String name;
  final String publisher;
  final Uint8List trayPng;
  final List<PayloadSticker> stickers;
}

class PayloadSticker {
  const PayloadSticker({required this.webp, this.emojis = const []});

  final Uint8List webp;
  final List<String> emojis;
}

/// WhatsApp sticker export: lossy WebP encoding (which exists in this app
/// solely to feed WhatsApp) plus the per-platform pack handoff.
abstract interface class StickerPackInstaller {
  /// Encodes raw RGBA pixels as lossy WebP no larger than [maxBytes], or
  /// null when no quality setting fits.
  Future<Uint8List?> encodeWebp(
    Uint8List rgba, {
    required int width,
    required int height,
    required int maxBytes,
  });

  /// Directory the Android sticker ContentProvider serves from; null on
  /// iOS. Native owns the path so Dart and the provider cannot disagree.
  Future<String?> exportDirectoryPath();

  /// Android: fires the ENABLE_STICKER_PACK intent for a pack already
  /// written to the export directory.
  Future<InstallStickerPackResult> enableStickerPack({
    required String identifier,
    required String name,
  });

  /// iOS: places the pack on the pasteboard and opens WhatsApp.
  Future<InstallStickerPackResult> sendToWhatsApp(StickerPackPayload payload);
}
