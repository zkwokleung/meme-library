import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/incoming_share_service.dart';
import 'package:meme_library/src/services/platform/share_service.dart';
import 'package:meme_library/src/services/providers.dart';

class _FakeClipboardService implements ClipboardService {
  ClipboardImage? stored;

  @override
  Future<ClipboardImage?> readImage() async => stored;

  @override
  Future<bool> writeImage(ClipboardImage image) async {
    stored = image;
    return true;
  }
}

class _FakeShareService implements ShareService {
  final sharedPaths = <String>[];

  @override
  Future<void> shareFile(String absolutePath, {String? mimeType}) async {
    sharedPaths.add(absolutePath);
  }
}

class _FakeIncomingShareService implements IncomingShareService {
  @override
  Future<List<IncomingSharedFile>> takeInitialShares() async => const [];

  @override
  Stream<List<IncomingSharedFile>> get incomingShares => const Stream.empty();
}

void main() {
  test('service providers throw until overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(clipboardServiceProvider),
      throwsA(isA<Object>()),
    );
    expect(() => container.read(shareServiceProvider), throwsA(isA<Object>()));
    expect(
      () => container.read(incomingShareServiceProvider),
      throwsA(isA<Object>()),
    );
  });

  test('service providers can be overridden with fakes', () async {
    final clipboard = _FakeClipboardService();
    final share = _FakeShareService();
    final container = ProviderContainer(
      overrides: [
        clipboardServiceProvider.overrideWithValue(clipboard),
        shareServiceProvider.overrideWithValue(share),
        incomingShareServiceProvider.overrideWithValue(
          _FakeIncomingShareService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final image = ClipboardImage(bytes: Uint8List.fromList([1, 2, 3]));
    await container.read(clipboardServiceProvider).writeImage(image);
    final read = await container.read(clipboardServiceProvider).readImage();
    expect(read, same(image));

    await container.read(shareServiceProvider).shareFile('/tmp/a.png');
    expect(share.sharedPaths, ['/tmp/a.png']);

    final initial = await container
        .read(incomingShareServiceProvider)
        .takeInitialShares();
    expect(initial, isEmpty);
  });
}
