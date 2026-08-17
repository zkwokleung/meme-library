import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/image_pipeline.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/domain/sticker_pack.dart';
import 'package:meme_library/src/import/import_coordinator.dart';
import 'package:meme_library/src/services/platform/sticker_pack_installer.dart';
import 'package:meme_library/src/stickers/whatsapp_sticker_exporter.dart';
import 'package:path/path.dart' as p;

import '../helpers/image_fixtures.dart';
import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() => harness.dispose());

  WhatsAppStickerExporter exporter({required bool ios}) =>
      WhatsAppStickerExporter(
        packs: harness.stickerPacks,
        mediaStore: harness.mediaStore,
        pipeline: const InlineImagePipeline(),
        installer: harness.stickerPackInstaller,
        isIOS: () => ios,
      );

  Future<Meme> importAnimated() async {
    final coordinator = ImportCoordinator(
      repository: harness.repository,
      mediaStore: harness.mediaStore,
      pipeline: const InlineImagePipeline(),
    );
    final outcome = await coordinator.importBytes(
      animatedGifBytes(),
      sourceKind: MemeSourceKind.clipboard,
    );
    return (outcome as ImportSuccess).meme;
  }

  Future<StickerPack> packWithMemes(int count, {String name = 'Pack'}) async {
    final pack = await harness.stickerPacks.createPack(name);
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      ids.add((await harnessImport(harness, seed: 100 * name.length + i)).id);
    }
    await harness.stickerPacks.addMemes(pack.id, ids);
    return (await harness.stickerPacks.packById(pack.id))!;
  }

  test('iOS handoff sends the encoded payload to WhatsApp', () async {
    final pack = await packWithMemes(3);
    await harness.stickerPacks.setEmojis(pack.id, pack.items.first.meme.id, [
      '😀',
    ]);

    final outcome = await exporter(ios: true).export(pack.id);

    expect(outcome.result, InstallStickerPackResult.started);
    expect(outcome.stickerCount, 3);
    expect(outcome.failedMemeIds, isEmpty);

    final payload = harness.stickerPackInstaller.sentPayloads.single;
    expect(payload.identifier, pack.id);
    expect(payload.name, pack.name);
    expect(payload.publisher, StickerPack.defaultPublisher);
    expect(payload.trayPng, isNotEmpty);
    expect(payload.stickers, hasLength(3));
    expect(payload.stickers.first.emojis, ['😀']);
    expect(payload.stickers.last.emojis, isEmpty);
    expect(harness.stickerPackInstaller.encodeCount, 3);
  });

  test('a pack below the minimum never reaches WhatsApp', () async {
    final pack = await packWithMemes(2);

    final outcome = await exporter(ios: true).export(pack.id);

    expect(outcome.result, InstallStickerPackResult.failed);
    expect(outcome.error, StickerExportError.tooFewStickers);
    expect(harness.stickerPackInstaller.sentPayloads, isEmpty);
  });

  test('animated memes are skipped and reported, not exported', () async {
    final pack = await packWithMemes(3);
    final animated = await importAnimated();
    await harness.stickerPacks.addMemes(pack.id, [animated.id]);

    final outcome = await exporter(ios: true).export(pack.id);

    expect(outcome.result, InstallStickerPackResult.started);
    expect(outcome.stickerCount, 3);
    expect(outcome.failedMemeIds, [animated.id]);
    expect(
      harness.stickerPackInstaller.sentPayloads.single.stickers,
      hasLength(3),
    );
  });

  test('stickers that cannot fit the size cap fail the export', () async {
    final pack = await packWithMemes(3);
    harness.stickerPackInstaller.encodedWebp = null;

    final outcome = await exporter(ios: true).export(pack.id);

    expect(outcome.result, InstallStickerPackResult.failed);
    expect(outcome.error, StickerExportError.tooFewStickers);
    expect(outcome.failedMemeIds, hasLength(3));
  });

  test('an unknown pack fails without touching the installer', () async {
    final outcome = await exporter(ios: true).export('missing');

    expect(outcome.result, InstallStickerPackResult.failed);
    expect(outcome.error, StickerExportError.packNotFound);
    expect(harness.stickerPackInstaller.encodeCount, 0);
  });

  test('Android without an export directory fails locally', () async {
    final pack = await packWithMemes(3);

    final outcome = await exporter(ios: false).export(pack.id);

    expect(outcome.result, InstallStickerPackResult.failed);
    expect(outcome.error, StickerExportError.exportUnavailable);
    expect(harness.stickerPackInstaller.enabledPacks, isEmpty);
  });

  test(
    'Android export writes the provider tree and fires the intent',
    () async {
      final exportDir = Directory(p.join(harness.root.path, 'sticker_packs'));
      harness.stickerPackInstaller.exportDirectory = exportDir.path;
      final pack = await packWithMemes(3);
      await harness.stickerPacks.setEmojis(pack.id, pack.items.first.meme.id, [
        '🔥',
      ]);
      final current = (await harness.stickerPacks.packById(pack.id))!;

      final outcome = await exporter(ios: false).export(pack.id);

      expect(outcome.result, InstallStickerPackResult.added);
      expect(harness.stickerPackInstaller.enabledPacks.single, (
        identifier: pack.id,
        name: pack.name,
      ));

      final packDir = Directory(p.join(exportDir.path, pack.id));
      expect(File(p.join(packDir.path, 'tray.png')).existsSync(), isTrue);
      for (final item in current.items) {
        expect(
          File(p.join(packDir.path, '${item.meme.id}.webp')).existsSync(),
          isTrue,
        );
      }

      final manifest =
          jsonDecode(
                File(
                  p.join(exportDir.path, 'contents.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(manifest['android_play_store_link'], '');
      final entry =
          (manifest['sticker_packs']! as List).single as Map<String, Object?>;
      expect(entry['identifier'], pack.id);
      expect(entry['name'], pack.name);
      expect(entry['publisher'], StickerPack.defaultPublisher);
      expect(entry['tray_image_file'], 'tray.png');
      expect(
        entry['image_data_version'],
        '${current.updatedAt.millisecondsSinceEpoch}',
      );
      expect(entry['animated_sticker_pack'], false);
      final stickers = entry['stickers']! as List;
      expect(stickers, hasLength(3));
      expect(
        (stickers.first as Map)['image_file'],
        '${current.items.first.meme.id}.webp',
      );
      expect((stickers.first as Map)['emojis'], ['🔥']);
      expect((stickers.first as Map)['accessibility_text'], '');
    },
  );

  test('re-export keeps other packs and drops deleted ones', () async {
    final exportDir = Directory(p.join(harness.root.path, 'sticker_packs'));
    harness.stickerPackInstaller.exportDirectory = exportDir.path;
    final packA = await packWithMemes(3, name: 'AAA');
    final packB = await packWithMemes(3, name: 'BBBB');

    await exporter(ios: false).export(packA.id);
    await exporter(ios: false).export(packB.id);

    Map<String, Object?> manifest() =>
        jsonDecode(
              File(p.join(exportDir.path, 'contents.json')).readAsStringSync(),
            )
            as Map<String, Object?>;
    Set<Object?> manifestIds() => {
      for (final entry in manifest()['sticker_packs']! as List)
        (entry as Map)['identifier'],
    };

    expect(manifestIds(), {packA.id, packB.id});
    expect(Directory(p.join(exportDir.path, packA.id)).existsSync(), isTrue);

    await harness.stickerPacks.deletePack(packA.id);
    await exporter(ios: false).export(packB.id);

    expect(manifestIds(), {packB.id});
    expect(Directory(p.join(exportDir.path, packA.id)).existsSync(), isFalse);
    expect(Directory(p.join(exportDir.path, packB.id)).existsSync(), isTrue);
  });
}
