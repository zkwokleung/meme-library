import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/services/platform/clipboard_service.dart';
import 'package:meme_library/src/services/platform/gallery_picker.dart';
import 'package:meme_library/src/services/platform/incoming_share_service.dart';
import 'package:meme_library/src/services/platform/share_service.dart';
import 'package:meme_library/src/services/providers.dart';

import '../helpers/test_harness.dart';

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
  Future<void> shareFiles(List<ShareableFile> files) async {
    sharedPaths.addAll([for (final file in files) file.absolutePath]);
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
    expect(() => container.read(galleryPickerProvider), throwsA(isA<Object>()));
    expect(
      () => container.read(heicTranscoderProvider),
      throwsA(isA<Object>()),
    );
  });

  test('service providers can be overridden with fakes', () async {
    final clipboard = _FakeClipboardService();
    final share = _FakeShareService();
    final gallery = FakeGalleryPicker()
      ..picked = [const PickedGalleryImage(path: '/tmp/pick.png')];
    final heic = FakeHeicTranscoder()
      ..result = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
    final container = ProviderContainer(
      overrides: [
        clipboardServiceProvider.overrideWithValue(clipboard),
        shareServiceProvider.overrideWithValue(share),
        incomingShareServiceProvider.overrideWithValue(
          _FakeIncomingShareService(),
        ),
        galleryPickerProvider.overrideWithValue(gallery),
        heicTranscoderProvider.overrideWithValue(heic),
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

    final picked = await container.read(galleryPickerProvider).pickImages();
    expect(picked.single.path, '/tmp/pick.png');

    final jpeg = await container
        .read(heicTranscoderProvider)
        .transcodeToJpeg('/tmp/x.heic');
    expect(jpeg, isNotNull);
    expect(heic.calls, ['/tmp/x.heic']);
  });
}
