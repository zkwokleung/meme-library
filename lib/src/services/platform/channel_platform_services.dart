import 'dart:async';

import 'package:flutter/services.dart';

import 'clipboard_service.dart';
import 'gallery_picker.dart';
import 'incoming_share_service.dart';
import 'sticker_pack_installer.dart';
import 'update_installer.dart';

/// Method channel shared by the platform service implementations.
const platformChannel = MethodChannel('com.zkwokleung.memelibrary/platform');

/// Event channel that surfaces share intents while the app is running.
const incomingSharesChannel = EventChannel(
  'com.zkwokleung.memelibrary/incoming_shares',
);

/// Clipboard access backed by native code: `UIPasteboard` on iOS and
/// `ClipboardManager` + FileProvider content URIs on Android.
class ChannelClipboardService implements ClipboardService {
  const ChannelClipboardService([this._channel = platformChannel]);

  final MethodChannel _channel;

  @override
  Future<ClipboardImage?> readImage() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'clipboard.readImage',
    );
    final bytes = result?['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    return ClipboardImage(
      bytes: bytes,
      suggestedName: result?['name'] as String?,
    );
  }

  @override
  Future<bool> writeImage(ClipboardImage image) async {
    final ok = await _channel.invokeMethod<bool>('clipboard.writeImage', {
      'bytes': image.bytes,
      'name': image.suggestedName,
    });
    return ok ?? false;
  }
}

/// Incoming shares backed by native code: `ACTION_SEND`/`ACTION_SEND_MULTIPLE`
/// on Android and an App Group inbox filled by the iOS share extension.
class ChannelIncomingShareService implements IncomingShareService {
  ChannelIncomingShareService([
    this._channel = platformChannel,
    this._events = incomingSharesChannel,
  ]);

  final MethodChannel _channel;
  final EventChannel _events;

  @override
  Future<List<IncomingSharedFile>> takeInitialShares() async {
    final result = await _channel.invokeListMethod<Object?>(
      'shares.takeInitial',
    );
    return _parse(result);
  }

  @override
  Stream<List<IncomingSharedFile>> get incomingShares => _events
      .receiveBroadcastStream()
      .map((event) => _parse(event as List<Object?>?));

  static List<IncomingSharedFile> _parse(List<Object?>? raw) => [
    for (final entry in raw ?? const <Object?>[])
      if (entry is Map && entry['path'] is String)
        IncomingSharedFile(
          path: entry['path']! as String,
          mimeType: entry['mimeType'] as String?,
        ),
  ];
}

/// Photo gallery access backed by native code: `PHPickerViewController` on
/// iOS, which returns each asset's original bytes and so preserves
/// animation that a `UIImage` round trip would flatten.
class ChannelGalleryPicker implements GalleryPicker {
  const ChannelGalleryPicker([this._channel = platformChannel]);

  final MethodChannel _channel;

  @override
  Future<List<PickedGalleryImage>> pickImages() async {
    final result = await _channel.invokeListMethod<Object?>(
      'gallery.pickImages',
    );
    return [
      for (final entry in result ?? const <Object?>[])
        if (entry is Map && entry['path'] is String)
          PickedGalleryImage(
            path: entry['path']! as String,
            displayName: ImagePickerGalleryPicker.meaningfulDisplayName(
              entry['name'] as String?,
            ),
          ),
    ];
  }
}

/// Update plumbing backed by native code: the package-installer intent and
/// `PackageManager` on Android. iOS implements only the version lookup and
/// URL opening; `installApk` is unimplemented there and reads as failed.
class ChannelUpdateInstaller implements UpdateInstaller {
  const ChannelUpdateInstaller([this._channel = platformChannel]);

  final MethodChannel _channel;

  @override
  Future<String?> installedVersion() async {
    try {
      return await _channel.invokeMethod<String>('app.getVersion');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<InstallApkResult> installApk(String path) async {
    try {
      final result = await _channel.invokeMethod<String>('updates.installApk', {
        'path': path,
      });
      return switch (result) {
        'started' => InstallApkResult.started,
        'permissionRequested' => InstallApkResult.permissionRequested,
        _ => InstallApkResult.failed,
      };
    } on PlatformException {
      return InstallApkResult.failed;
    } on MissingPluginException {
      return InstallApkResult.failed;
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    // The URL comes from remote release metadata; only https ever reaches
    // the platform. Both native handlers enforce the same rule.
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https')) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('system.openUrl', {
        'url': url,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// WhatsApp sticker export backed by native code: `Bitmap.compress` and the
/// ENABLE_STICKER_PACK intent on Android, libwebp and the pasteboard
/// handoff on iOS. Every call can fail for reasons outside the app
/// (WhatsApp missing, user cancels), so results degrade to sentinels.
class ChannelStickerPackInstaller implements StickerPackInstaller {
  const ChannelStickerPackInstaller([this._channel = platformChannel]);

  final MethodChannel _channel;

  @override
  Future<Uint8List?> encodeWebp(
    Uint8List rgba, {
    required int width,
    required int height,
    required int maxBytes,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'stickers.encodeWebp',
        {'rgba': rgba, 'width': width, 'height': height, 'maxBytes': maxBytes},
      );
      final bytes = result?['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) return null;
      return bytes;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String?> exportDirectoryPath() async {
    try {
      final path = await _channel.invokeMethod<String>(
        'stickers.getExportDirectory',
      );
      return (path == null || path.isEmpty) ? null : path;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<InstallStickerPackResult> enableStickerPack({
    required String identifier,
    required String name,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'stickers.enableStickerPack',
        {'identifier': identifier, 'name': name},
      );
      return _parseInstallResult(result);
    } on PlatformException {
      return InstallStickerPackResult.failed;
    } on MissingPluginException {
      return InstallStickerPackResult.failed;
    }
  }

  @override
  Future<InstallStickerPackResult> sendToWhatsApp(
    StickerPackPayload payload,
  ) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'stickers.sendToWhatsApp',
        {
          'identifier': payload.identifier,
          'name': payload.name,
          'publisher': payload.publisher,
          'trayPng': payload.trayPng,
          'stickers': [
            for (final sticker in payload.stickers)
              {'webp': sticker.webp, 'emojis': sticker.emojis},
          ],
        },
      );
      return _parseInstallResult(result);
    } on PlatformException {
      return InstallStickerPackResult.failed;
    } on MissingPluginException {
      return InstallStickerPackResult.failed;
    }
  }

  static InstallStickerPackResult _parseInstallResult(String? result) =>
      switch (result) {
        'added' => InstallStickerPackResult.added,
        'started' => InstallStickerPackResult.started,
        'cancelled' => InstallStickerPackResult.cancelled,
        'whatsappNotInstalled' => InstallStickerPackResult.whatsappNotInstalled,
        _ => InstallStickerPackResult.failed,
      };
}

/// HEIC/HEIF conversion backed by native code: `ImageIO` on iOS and
/// `ImageDecoder` on Android, both of which bake the container's rotation
/// into the JPEG they return.
class ChannelHeicTranscoder implements HeicTranscoder {
  const ChannelHeicTranscoder([this._channel = platformChannel]);

  final MethodChannel _channel;

  @override
  Future<Uint8List?> transcodeToJpeg(String path) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'image.transcodeToJpeg',
      {'path': path},
    );
    final bytes = result?['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    return bytes;
  }
}
