import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/services/platform/channel_platform_services.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(platformChannel, null);
  });

  group('ChannelClipboardService', () {
    test('readImage decodes the platform payload', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'clipboard.readImage');
        return {'bytes': bytes, 'name': 'x.png'};
      });

      final image = await const ChannelClipboardService().readImage();
      expect(image!.bytes, bytes);
      expect(image.suggestedName, 'x.png');
    });

    test('readImage returns null for empty or missing payloads', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async => null);
      expect(await const ChannelClipboardService().readImage(), isNull);

      messenger.setMockMethodCallHandler(
        platformChannel,
        (call) async => {'bytes': Uint8List(0)},
      );
      expect(await const ChannelClipboardService().readImage(), isNull);
    });

    test('writeImage forwards bytes and reports platform result', () async {
      late Map<Object?, Object?> sent;
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'clipboard.writeImage');
        sent = call.arguments as Map<Object?, Object?>;
        return true;
      });

      final ok = await const ChannelClipboardService().writeImage(
        ClipboardImage(
          bytes: Uint8List.fromList([9, 9]),
          suggestedName: 'meme.png',
        ),
      );
      expect(ok, isTrue);
      expect(sent['name'], 'meme.png');
      expect(sent['bytes'], isA<Uint8List>());
    });

    test('writeImage treats a missing result as unsupported', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async => null);
      final ok = await const ChannelClipboardService().writeImage(
        ClipboardImage(bytes: Uint8List.fromList([1])),
      );
      expect(ok, isFalse);
    });
  });

  group('ChannelIncomingShareService', () {
    test('takeInitialShares parses the staged file list', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'shares.takeInitial');
        return [
          {'path': '/tmp/a', 'mimeType': 'image/png'},
          {'path': '/tmp/b', 'mimeType': null},
        ];
      });

      final shares = await ChannelIncomingShareService().takeInitialShares();
      expect(shares, hasLength(2));
      expect(shares.first.path, '/tmp/a');
      expect(shares.first.mimeType, 'image/png');
      expect(shares.last.mimeType, isNull);
    });

    test('takeInitialShares tolerates an empty response', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async => []);
      expect(await ChannelIncomingShareService().takeInitialShares(), isEmpty);
    });
  });
}
