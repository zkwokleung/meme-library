import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/meme.dart';
import '../domain/sticker_pack.dart';
import 'database/app_database.dart';

/// Persistence boundary for WhatsApp sticker packs.
abstract interface class StickerPackRepository {
  /// Emits whenever pack content may have changed, including meme
  /// deletions that cascade into packs.
  Stream<void> get changes;

  /// Newest pack first.
  Future<List<StickerPackSummary>> allPacks();

  Future<StickerPack?> packById(String id);

  Future<StickerPack> createPack(String name);

  Future<void> renamePack(String id, String name);

  Future<void> deletePack(String id);

  /// Appends memes to the pack in the given order, skipping ones already
  /// in the pack or missing from the library, and stopping at
  /// [StickerPack.maxStickers].
  Future<({int added, int skippedDuplicates, int skippedOverCapacity})>
  addMemes(String packId, List<String> memeIds);

  Future<void> removeMeme(String packId, String memeId);

  /// Replaces the emoji set of a sticker; at most
  /// [StickerPack.maxEmojisPerSticker] entries.
  Future<void> setEmojis(String packId, String memeId, List<String> emojis);
}

class DriftStickerPackRepository implements StickerPackRepository {
  DriftStickerPackRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _previewLimit = 4;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<void> get changes =>
      _db.tableUpdates(TableUpdateQuery.any()).map((_) {});

  @override
  Future<List<StickerPackSummary>> allPacks() async {
    final packs =
        await (_db.select(_db.stickerPacks)..orderBy([
              (p) => OrderingTerm.desc(p.createdAt),
              (p) => OrderingTerm.desc(p.id),
            ]))
            .get();
    if (packs.isEmpty) return const [];

    final itemRows = await _db
        .customSelect(
          'SELECT spi.pack_id AS pack_id, m.thumbnail_path AS thumbnail_path '
          'FROM sticker_pack_items spi '
          'JOIN memes m ON m.id = spi.meme_id '
          'ORDER BY spi.pack_id, spi.position',
        )
        .get();
    final counts = <String, int>{};
    final previews = <String, List<String>>{};
    for (final row in itemRows) {
      final packId = row.read<String>('pack_id');
      counts[packId] = (counts[packId] ?? 0) + 1;
      final paths = previews.putIfAbsent(packId, () => []);
      if (paths.length < _previewLimit) {
        paths.add(row.read<String>('thumbnail_path'));
      }
    }

    return [
      for (final pack in packs)
        StickerPackSummary(
          id: pack.id,
          name: pack.name,
          stickerCount: counts[pack.id] ?? 0,
          previewThumbnailPaths: previews[pack.id] ?? const [],
        ),
    ];
  }

  @override
  Future<StickerPack?> packById(String id) async {
    final pack = await (_db.select(
      _db.stickerPacks,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (pack == null) return null;

    final itemQuery = _db.select(_db.stickerPackItems).join([
      innerJoin(_db.memes, _db.memes.id.equalsExp(_db.stickerPackItems.memeId)),
    ])..where(_db.stickerPackItems.packId.equals(id));
    itemQuery.orderBy([OrderingTerm.asc(_db.stickerPackItems.position)]);
    final rows = await itemQuery.get();

    return _toDomain(pack, [
      for (final row in rows)
        StickerPackItem(
          meme: _memeToDomain(row.readTable(_db.memes)),
          position: row.readTable(_db.stickerPackItems).position,
          emojis: _decodeEmojis(row.readTable(_db.stickerPackItems).emojis),
        ),
    ]);
  }

  @override
  Future<StickerPack> createPack(String name) async {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final row = StickerPackRow(
      id: _uuid.v4(),
      name: name,
      publisher: StickerPack.defaultPublisher,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.stickerPacks).insert(row);
    return _toDomain(row, const []);
  }

  @override
  Future<void> renamePack(String id, String name) => _db.transaction(() async {
    await (_db.update(_db.stickerPacks)..where((p) => p.id.equals(id))).write(
      StickerPacksCompanion(name: Value(name), updatedAt: Value(_nowMillis())),
    );
  });

  @override
  Future<void> deletePack(String id) async {
    await (_db.delete(_db.stickerPacks)..where((p) => p.id.equals(id))).go();
  }

  @override
  Future<({int added, int skippedDuplicates, int skippedOverCapacity})>
  addMemes(String packId, List<String> memeIds) => _db.transaction(() async {
    final existing =
        (await (_db.selectOnly(_db.stickerPackItems)
                  ..addColumns([_db.stickerPackItems.memeId])
                  ..where(_db.stickerPackItems.packId.equals(packId)))
                .get())
            .map((row) => row.read(_db.stickerPackItems.memeId)!)
            .toSet();
    final known =
        (await (_db.selectOnly(_db.memes)
                  ..addColumns([_db.memes.id])
                  ..where(_db.memes.id.isIn(memeIds)))
                .get())
            .map((row) => row.read(_db.memes.id)!)
            .toSet();

    var skippedDuplicates = 0;
    final candidates = <String>[];
    for (final memeId in memeIds) {
      if (!known.contains(memeId) || candidates.contains(memeId)) continue;
      if (existing.contains(memeId)) {
        skippedDuplicates++;
      } else {
        candidates.add(memeId);
      }
    }

    final capacity = StickerPack.maxStickers - existing.length;
    final accepted = capacity > 0
        ? candidates.take(capacity).toList()
        : const <String>[];

    if (accepted.isNotEmpty) {
      final maxPosition =
          (await _db
                  .customSelect(
                    'SELECT COALESCE(MAX(position), -1) AS p '
                    'FROM sticker_pack_items WHERE pack_id = ?',
                    variables: [Variable(packId)],
                  )
                  .getSingle())
              .read<int>('p');
      var position = maxPosition + 1;
      for (final memeId in accepted) {
        await _db
            .into(_db.stickerPackItems)
            .insert(
              StickerPackItemsCompanion.insert(
                packId: packId,
                memeId: memeId,
                position: position++,
              ),
            );
      }
      await _touchPack(packId);
    }

    return (
      added: accepted.length,
      skippedDuplicates: skippedDuplicates,
      skippedOverCapacity: candidates.length - accepted.length,
    );
  });

  @override
  Future<void> removeMeme(String packId, String memeId) => _db.transaction(
    () async {
      final removed = await (_db.delete(
        _db.stickerPackItems,
      )..where((i) => i.packId.equals(packId) & i.memeId.equals(memeId))).go();
      if (removed > 0) await _touchPack(packId);
    },
  );

  @override
  Future<void> setEmojis(String packId, String memeId, List<String> emojis) {
    if (emojis.length > StickerPack.maxEmojisPerSticker) {
      throw ArgumentError.value(
        emojis,
        'emojis',
        'at most ${StickerPack.maxEmojisPerSticker} allowed',
      );
    }
    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.stickerPackItems)..where(
                (i) => i.packId.equals(packId) & i.memeId.equals(memeId),
              ))
              .write(
                StickerPackItemsCompanion(
                  emojis: Value(emojis.isEmpty ? null : jsonEncode(emojis)),
                ),
              );
      if (updated > 0) await _touchPack(packId);
    });
  }

  Future<void> _touchPack(String packId) async {
    await (_db.update(_db.stickerPacks)..where((p) => p.id.equals(packId)))
        .write(StickerPacksCompanion(updatedAt: Value(_nowMillis())));
  }

  int _nowMillis() => _clock().toUtc().millisecondsSinceEpoch;

  List<String> _decodeEmojis(String? json) => json == null
      ? const []
      : [
          for (final emoji in jsonDecode(json) as List<Object?>)
            emoji! as String,
        ];

  StickerPack _toDomain(
    StickerPackRow row,
    List<StickerPackItem> items,
  ) => StickerPack(
    id: row.id,
    name: row.name,
    publisher: row.publisher,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    items: items,
  );

  Meme _memeToDomain(MemeRow row) => Meme(
    id: row.id,
    sha256: row.sha256,
    mimeType: row.mimeType,
    width: row.width,
    height: row.height,
    sizeBytes: row.sizeBytes,
    relativePath: row.relativePath,
    thumbnailPath: row.thumbnailPath,
    sourceKind: MemeSourceKind.parse(row.sourceKind),
    sourceRef: row.sourceRef,
    title: row.title,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
