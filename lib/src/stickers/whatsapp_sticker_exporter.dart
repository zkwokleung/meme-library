import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../data/image_pipeline.dart';
import '../data/media_store.dart';
import '../data/sticker_images.dart';
import '../data/sticker_pack_repository.dart';
import '../domain/sticker_pack.dart';
import '../services/platform/sticker_pack_installer.dart';

/// Local reasons an export never reached WhatsApp.
enum StickerExportError { packNotFound, tooFewStickers, exportUnavailable }

class StickerExportOutcome {
  const StickerExportOutcome({
    required this.result,
    this.error,
    this.stickerCount = 0,
    this.failedMemeIds = const [],
  });

  final InstallStickerPackResult result;

  /// Set only when [result] is failed for a local reason.
  final StickerExportError? error;

  /// Stickers actually handed to WhatsApp.
  final int stickerCount;

  /// Memes dropped from the export: animated, unreadable, or impossible
  /// to fit under the WebP size cap.
  final List<String> failedMemeIds;
}

/// Encodes a pack's memes into WhatsApp-compliant stickers and hands the
/// pack over: on Android by writing the tree the sticker ContentProvider
/// serves and firing the add intent, on iOS via the pasteboard.
class WhatsAppStickerExporter {
  WhatsAppStickerExporter({
    required StickerPackRepository packs,
    required MediaStore mediaStore,
    required ImagePipeline pipeline,
    required StickerPackInstaller installer,
    bool Function()? isIOS,
  }) : _packs = packs,
       _mediaStore = mediaStore,
       _pipeline = pipeline,
       _installer = installer,
       _isIOS = isIOS ?? (() => Platform.isIOS);

  static const maxStickerBytes = 100 * 1024;

  final StickerPackRepository _packs;
  final MediaStore _mediaStore;
  final ImagePipeline _pipeline;
  final StickerPackInstaller _installer;
  final bool Function() _isIOS;

  Future<StickerExportOutcome> export(String packId) async {
    final pack = await _packs.packById(packId);
    if (pack == null) {
      return const StickerExportOutcome(
        result: InstallStickerPackResult.failed,
        error: StickerExportError.packNotFound,
      );
    }

    final encoded = <_EncodedSticker>[];
    final failedMemeIds = <String>[];
    for (final item in pack.items) {
      final sticker = await _encode(item);
      if (sticker == null) {
        failedMemeIds.add(item.meme.id);
      } else {
        encoded.add(sticker);
      }
    }

    if (encoded.length < StickerPack.minStickers) {
      return StickerExportOutcome(
        result: InstallStickerPackResult.failed,
        error: StickerExportError.tooFewStickers,
        failedMemeIds: failedMemeIds,
      );
    }

    if (_isIOS()) {
      final result = await _installer.sendToWhatsApp(
        StickerPackPayload(
          identifier: pack.id,
          name: pack.name,
          publisher: pack.publisher,
          trayPng: encoded.first.trayPng,
          stickers: [
            for (final sticker in encoded)
              PayloadSticker(webp: sticker.webp, emojis: sticker.item.emojis),
          ],
        ),
      );
      return StickerExportOutcome(
        result: result,
        stickerCount: encoded.length,
        failedMemeIds: failedMemeIds,
      );
    }

    final directory = await _installer.exportDirectoryPath();
    if (directory == null) {
      return StickerExportOutcome(
        result: InstallStickerPackResult.failed,
        error: StickerExportError.exportUnavailable,
        failedMemeIds: failedMemeIds,
      );
    }
    await _writeExportTree(Directory(directory), pack, encoded);
    final result = await _installer.enableStickerPack(
      identifier: pack.id,
      name: pack.name,
    );
    return StickerExportOutcome(
      result: result,
      stickerCount: encoded.length,
      failedMemeIds: failedMemeIds,
    );
  }

  Future<_EncodedSticker?> _encode(StickerPackItem item) async {
    final Uint8List bytes;
    try {
      bytes = await _mediaStore.resolve(item.meme.relativePath).readAsBytes();
    } on FileSystemException {
      return null;
    }
    final StickerSource source;
    try {
      source = await _pipeline.stickerSource(bytes);
    } on StickerImageException {
      return null;
    }
    final webp = await _installer.encodeWebp(
      source.rgba,
      width: stickerDimension,
      height: stickerDimension,
      maxBytes: maxStickerBytes,
    );
    if (webp == null) return null;
    return _EncodedSticker(item: item, webp: webp, trayPng: source.trayPng);
  }

  /// Rewrites `<root>/<packId>/` from this export, then regenerates
  /// contents.json: entries for other packs are carried over from the old
  /// manifest so they keep describing the files already on disk, and packs
  /// deleted from the database are dropped along with their directories.
  /// The manifest is written last (staging file + rename) so the provider
  /// never reads a manifest describing files that are not in place yet.
  Future<void> _writeExportTree(
    Directory root,
    StickerPack pack,
    List<_EncodedSticker> encoded,
  ) async {
    await root.create(recursive: true);

    final staging = Directory(p.join(root.path, '.staging-${pack.id}'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    await File(
      p.join(staging.path, 'tray.png'),
    ).writeAsBytes(encoded.first.trayPng);
    for (final sticker in encoded) {
      await File(
        p.join(staging.path, '${sticker.item.meme.id}.webp'),
      ).writeAsBytes(sticker.webp);
    }
    final packDir = Directory(p.join(root.path, pack.id));
    if (await packDir.exists()) await packDir.delete(recursive: true);
    await staging.rename(packDir.path);

    final manifestFile = File(p.join(root.path, 'contents.json'));
    final entries = <String, Map<String, Object?>>{};
    if (await manifestFile.exists()) {
      try {
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, Object?>;
        for (final entry
            in manifest['sticker_packs'] as List<Object?>? ?? const []) {
          if (entry is Map<String, Object?> && entry['identifier'] is String) {
            entries[entry['identifier']! as String] = entry;
          }
        }
      } on FormatException {
        // A corrupt manifest is rebuilt from scratch.
      }
    }

    final liveIds = {for (final summary in await _packs.allPacks()) summary.id};
    for (final staleId in entries.keys.toList()) {
      if (liveIds.contains(staleId)) continue;
      entries.remove(staleId);
      final staleDir = Directory(p.join(root.path, staleId));
      if (await staleDir.exists()) await staleDir.delete(recursive: true);
    }

    entries[pack.id] = {
      'identifier': pack.id,
      'name': pack.name,
      'publisher': pack.publisher,
      'tray_image_file': 'tray.png',
      'image_data_version': '${pack.updatedAt.millisecondsSinceEpoch}',
      'avoid_cache': false,
      'animated_sticker_pack': false,
      'publisher_email': '',
      'publisher_website': '',
      'privacy_policy_website': '',
      'license_agreement_website': '',
      'stickers': [
        for (final sticker in encoded)
          {
            'image_file': '${sticker.item.meme.id}.webp',
            'emojis': sticker.item.emojis,
            'accessibility_text': '',
          },
      ],
    };

    final stagedManifest = File(p.join(root.path, '.contents.json.staging'));
    await stagedManifest.writeAsString(
      jsonEncode({
        'android_play_store_link': '',
        'ios_app_store_link': '',
        'sticker_packs': entries.values.toList(),
      }),
    );
    await stagedManifest.rename(manifestFile.path);
  }
}

class _EncodedSticker {
  const _EncodedSticker({
    required this.item,
    required this.webp,
    required this.trayPng,
  });

  final StickerPackItem item;
  final Uint8List webp;
  final Uint8List trayPng;
}
