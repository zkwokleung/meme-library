import 'dart:async';

import 'package:flutter/services.dart';

import 'clipboard_service.dart';
import 'gallery_picker.dart';
import 'incoming_share_service.dart';

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
