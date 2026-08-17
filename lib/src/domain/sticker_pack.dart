import 'package:meta/meta.dart';

import 'meme.dart';

/// A sticker pack assembled from library memes for export to WhatsApp.
///
/// [id] doubles as the pack identifier handed to WhatsApp and [updatedAt]
/// as its `image_data_version`, so WhatsApp refreshes cached stickers
/// whenever the pack changes.
@immutable
class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.publisher,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  /// WhatsApp's limits for a valid static sticker pack.
  static const minStickers = 3;
  static const maxStickers = 30;
  static const maxEmojisPerSticker = 3;

  static const defaultPublisher = 'Meme Library';

  final String id;
  final String name;
  final String publisher;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ordered by position. Item memes carry no tags.
  final List<StickerPackItem> items;

  @override
  String toString() => 'StickerPack($id, $name, ${items.length} stickers)';
}

@immutable
class StickerPackItem {
  const StickerPackItem({
    required this.meme,
    required this.position,
    this.emojis = const [],
  });

  final Meme meme;
  final int position;

  /// Up to [StickerPack.maxEmojisPerSticker] emoji shown by WhatsApp's
  /// sticker search.
  final List<String> emojis;
}

/// Lightweight projection for the pack list.
@immutable
class StickerPackSummary {
  const StickerPackSummary({
    required this.id,
    required this.name,
    required this.stickerCount,
    required this.previewThumbnailPaths,
  });

  final String id;
  final String name;
  final int stickerCount;

  /// Media-root-relative thumbnail paths of the first few stickers.
  final List<String> previewThumbnailPaths;
}
