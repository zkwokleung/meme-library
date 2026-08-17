import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/sticker_pack_repository.dart';
import 'package:meme_library/src/domain/sticker_pack.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late DriftStickerPackRepository repository;

  setUp(() {
    db = AppDatabase.inMemory();
    now = DateTime.utc(2026, 1, 1);
    repository = DriftStickerPackRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<void> insertMeme(String id) => db
      .into(db.memes)
      .insert(
        MemesCompanion.insert(
          id: id,
          sha256: 'hash-$id',
          mimeType: 'image/png',
          width: 1,
          height: 1,
          sizeBytes: 10,
          relativePath: 'originals/$id.png',
          thumbnailPath: 'thumbs/${id}_t.png',
          sourceKind: 'clipboard',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<List<String>> insertMemes(int count) async {
    final ids = [for (var i = 0; i < count; i++) 'm$i'];
    for (final id in ids) {
      await insertMeme(id);
    }
    return ids;
  }

  test('creates packs and lists them newest first', () async {
    final first = await repository.createPack('Reactions');
    now = now.add(const Duration(minutes: 1));
    final second = await repository.createPack('Classics');

    expect(first.publisher, StickerPack.defaultPublisher);
    expect(first.createdAt, DateTime.utc(2026, 1, 1));

    final packs = await repository.allPacks();
    expect(packs.map((p) => p.id), [second.id, first.id]);
    expect(packs.first.stickerCount, 0);
    expect(packs.first.previewThumbnailPaths, isEmpty);
  });

  test('addMemes appends in order, skipping duplicates and unknowns', () async {
    final ids = await insertMemes(3);
    final pack = await repository.createPack('Pack');

    var result = await repository.addMemes(pack.id, [ids[0], ids[1]]);
    expect(result, (added: 2, skippedDuplicates: 0, skippedOverCapacity: 0));

    result = await repository.addMemes(pack.id, [ids[1], ids[2], 'ghost']);
    expect(result, (added: 1, skippedDuplicates: 1, skippedOverCapacity: 0));

    final loaded = await repository.packById(pack.id);
    expect(loaded!.items.map((i) => i.meme.id), [ids[0], ids[1], ids[2]]);
    expect(loaded.items.map((i) => i.position), [0, 1, 2]);
    expect(loaded.items.first.meme.thumbnailPath, 'thumbs/m0_t.png');
  });

  test('addMemes stops at pack capacity', () async {
    final ids = await insertMemes(StickerPack.maxStickers + 2);
    final pack = await repository.createPack('Big');

    final result = await repository.addMemes(pack.id, ids);
    expect(result.added, StickerPack.maxStickers);
    expect(result.skippedOverCapacity, 2);

    final followUp = await repository.addMemes(pack.id, [ids.last]);
    expect(followUp, (added: 0, skippedDuplicates: 0, skippedOverCapacity: 1));
  });

  test('mutations bump updatedAt; no-ops do not', () async {
    final ids = await insertMemes(1);
    final pack = await repository.createPack('Pack');

    now = now.add(const Duration(minutes: 1));
    await repository.addMemes(pack.id, ids);
    var loaded = await repository.packById(pack.id);
    expect(loaded!.updatedAt, now);

    now = now.add(const Duration(minutes: 1));
    await repository.removeMeme(pack.id, 'ghost');
    loaded = await repository.packById(pack.id);
    expect(loaded!.updatedAt, isNot(now));

    await repository.removeMeme(pack.id, ids.single);
    loaded = await repository.packById(pack.id);
    expect(loaded!.updatedAt, now);
    expect(loaded.items, isEmpty);
  });

  test('setEmojis stores, clears, and rejects more than three', () async {
    final ids = await insertMemes(1);
    final pack = await repository.createPack('Pack');
    await repository.addMemes(pack.id, ids);

    await repository.setEmojis(pack.id, ids.single, ['😀', '😂']);
    var loaded = await repository.packById(pack.id);
    expect(loaded!.items.single.emojis, ['😀', '😂']);

    await repository.setEmojis(pack.id, ids.single, []);
    loaded = await repository.packById(pack.id);
    expect(loaded!.items.single.emojis, isEmpty);

    expect(
      () => repository.setEmojis(pack.id, ids.single, ['a', 'b', 'c', 'd']),
      throwsArgumentError,
    );
  });

  test('rename updates the summary; delete cascades items', () async {
    final ids = await insertMemes(2);
    final pack = await repository.createPack('Old name');
    await repository.addMemes(pack.id, ids);

    await repository.renamePack(pack.id, 'New name');
    final summaries = await repository.allPacks();
    expect(summaries.single.name, 'New name');
    expect(summaries.single.stickerCount, 2);
    expect(summaries.single.previewThumbnailPaths, [
      'thumbs/m0_t.png',
      'thumbs/m1_t.png',
    ]);

    await repository.deletePack(pack.id);
    expect(await repository.allPacks(), isEmpty);
    expect(await db.select(db.stickerPackItems).get(), isEmpty);
  });

  test('deleting a meme cascades it out of packs', () async {
    final ids = await insertMemes(2);
    final pack = await repository.createPack('Pack');
    await repository.addMemes(pack.id, ids);

    await (db.delete(db.memes)..where((m) => m.id.equals(ids.first))).go();

    final loaded = await repository.packById(pack.id);
    expect(loaded!.items.map((i) => i.meme.id), [ids.last]);
  });

  test('packById returns null for unknown ids', () async {
    expect(await repository.packById('missing'), isNull);
  });

  test('changes emits on pack mutations', () async {
    final emitted = expectLater(repository.changes, emits(anything));
    await repository.createPack('Pack');
    await emitted;
  });
}
