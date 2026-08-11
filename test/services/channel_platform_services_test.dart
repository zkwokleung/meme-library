import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/services/platform/channel_platform_services.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/update_installer.dart';

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

  group('ChannelGalleryPicker', () {
    test('pickImages parses the staged file list in order', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'gallery.pickImages');
        return [
          {'path': '/tmp/a', 'name': 'IMG_1234.HEIC'},
          {'path': '/tmp/b', 'name': null},
        ];
      });

      final picked = await const ChannelGalleryPicker().pickImages();
      expect(picked.map((p) => p.path), ['/tmp/a', '/tmp/b']);
      expect(picked.first.displayName, 'IMG_1234.HEIC');
      expect(picked.last.displayName, isNull);
    });

    test('pickImages drops entries without a path', () async {
      messenger.setMockMethodCallHandler(
        platformChannel,
        (call) async => [
          'not a map',
          {'name': 'orphan.png'},
          {'path': '/tmp/ok', 'name': 'ok.png'},
        ],
      );
      final picked = await const ChannelGalleryPicker().pickImages();
      expect(picked.single.path, '/tmp/ok');
    });

    test('a cancelled pick is an empty list, not an error', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async => []);
      expect(await const ChannelGalleryPicker().pickImages(), isEmpty);

      messenger.setMockMethodCallHandler(platformChannel, (call) async => null);
      expect(await const ChannelGalleryPicker().pickImages(), isEmpty);
    });

    test('a picker scratch name is not treated as provenance', () async {
      messenger.setMockMethodCallHandler(
        platformChannel,
        (call) async => [
          {'path': '/tmp/a', 'name': 'image_picker_9f8e7d.jpg'},
        ],
      );
      final picked = await const ChannelGalleryPicker().pickImages();
      expect(picked.single.displayName, isNull);
    });
  });

  group('ChannelUpdateInstaller', () {
    test('installedVersion returns the platform version string', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'app.getVersion');
        return '1.2.3';
      });

      expect(await const ChannelUpdateInstaller().installedVersion(), '1.2.3');
    });

    test('installedVersion tolerates null and platform errors', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async => null);
      expect(await const ChannelUpdateInstaller().installedVersion(), isNull);

      messenger.setMockMethodCallHandler(
        platformChannel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      expect(await const ChannelUpdateInstaller().installedVersion(), isNull);
    });

    test('installApk forwards the path and maps the result', () async {
      const results = {
        'started': InstallApkResult.started,
        'permissionRequested': InstallApkResult.permissionRequested,
        'failed': InstallApkResult.failed,
        'garbage': InstallApkResult.failed,
        null: InstallApkResult.failed,
      };
      for (final entry in results.entries) {
        messenger.setMockMethodCallHandler(platformChannel, (call) async {
          expect(call.method, 'updates.installApk');
          expect((call.arguments as Map)['path'], '/tmp/app.apk');
          return entry.key;
        });
        expect(
          await const ChannelUpdateInstaller().installApk('/tmp/app.apk'),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('installApk reads as failed where unimplemented', () async {
      messenger.setMockMethodCallHandler(
        platformChannel,
        (call) async => throw MissingPluginException(),
      );
      expect(
        await const ChannelUpdateInstaller().installApk('/tmp/app.apk'),
        InstallApkResult.failed,
      );
    });

    test(
      'openUrl rejects non-https urls before reaching the channel',
      () async {
        messenger.setMockMethodCallHandler(platformChannel, (call) async {
          fail('the channel must not be invoked for ${call.arguments}');
        });
        for (final bad in [
          'http://example.com/x',
          'file:///etc/passwd',
          'intent://scan/#Intent;end',
          'not a url',
        ]) {
          expect(
            await const ChannelUpdateInstaller().openUrl(bad),
            isFalse,
            reason: bad,
          );
        }
      },
    );

    test('openUrl forwards the url and reports the outcome', () async {
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'system.openUrl');
        expect((call.arguments as Map)['url'], 'https://example.com');
        return true;
      });
      expect(
        await const ChannelUpdateInstaller().openUrl('https://example.com'),
        isTrue,
      );

      messenger.setMockMethodCallHandler(platformChannel, (call) async => null);
      expect(
        await const ChannelUpdateInstaller().openUrl('https://example.com'),
        isFalse,
      );
    });
  });

  group('ChannelHeicTranscoder', () {
    test('transcodeToJpeg forwards the path and returns bytes', () async {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        expect(call.method, 'image.transcodeToJpeg');
        expect((call.arguments as Map)['path'], '/tmp/x.heic');
        return {'bytes': bytes};
      });

      final result = await const ChannelHeicTranscoder().transcodeToJpeg(
        '/tmp/x.heic',
      );
      expect(result, bytes);
    });

    test('an undecodable source is null, not an exception', () async {
      for (final payload in <Object?>[
        null,
        <String, Object?>{},
        {'bytes': Uint8List(0)},
      ]) {
        messenger.setMockMethodCallHandler(
          platformChannel,
          (call) async => payload,
        );
        expect(
          await const ChannelHeicTranscoder().transcodeToJpeg('/tmp/x.heic'),
          isNull,
          reason: '$payload',
        );
      }
    });
  });
}
