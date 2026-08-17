import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:path/path.dart' as p;

/// The exact schema version 1 produced, frozen verbatim so migration tests
/// keep starting from what shipped even as the live schema moves on.
const _v1Schema = [
  'CREATE TABLE "memes" ("id" TEXT NOT NULL, "sha256" TEXT NOT NULL UNIQUE, '
      '"mime_type" TEXT NOT NULL, "width" INTEGER NOT NULL, '
      '"height" INTEGER NOT NULL, "size_bytes" INTEGER NOT NULL, '
      '"relative_path" TEXT NOT NULL, "thumbnail_path" TEXT NOT NULL, '
      '"source_kind" TEXT NOT NULL, "source_ref" TEXT NULL, '
      '"title" TEXT NULL, "notes" TEXT NULL, "created_at" INTEGER NOT NULL, '
      '"updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "tags" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, '
      '"normalized_name" TEXT NOT NULL UNIQUE, PRIMARY KEY ("id"))',
  'CREATE TABLE "meme_tags" ("meme_id" TEXT NOT NULL REFERENCES memes (id) '
      'ON DELETE CASCADE, "tag_id" TEXT NOT NULL REFERENCES tags (id) '
      'ON DELETE CASCADE, PRIMARY KEY ("meme_id", "tag_id"))',
  'CREATE VIRTUAL TABLE meme_fts USING fts5('
      'meme_id UNINDEXED, title, notes, source_name, tag_names, '
      "tokenize='unicode61 remove_diacritics 2')",
  'CREATE INDEX idx_memes_created_at ON memes (created_at DESC)',
  'CREATE INDEX idx_meme_tags_tag_id ON meme_tags (tag_id)',
];

/// Opens an executor at schema version 1 without running any migrations,
/// so a test can lay down the frozen v1 schema by hand.
class _V1SchemaUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('creates schema with tables, FTS index, and foreign keys', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
        )
        .get();
    final names = tables.map((row) => row.read<String>('name')).toSet();

    expect(
      names,
      containsAll([
        'memes',
        'tags',
        'meme_tags',
        'meme_fts',
        'sticker_packs',
        'sticker_pack_items',
      ]),
    );
    expect(names, contains('idx_memes_created_at'));
    expect(names, contains('idx_meme_tags_tag_id'));
    expect(names, contains('idx_sticker_pack_items_meme_id'));

    final fkRow = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fkRow.read<int>('foreign_keys'), 1);
  });

  test('FTS5 matches indexed content', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    await db.customStatement(
      'INSERT INTO meme_fts (meme_id, title, notes, source_name, tag_names) '
      "VALUES ('m1', 'Distracted boyfriend', 'classic', 'boyfriend.png', "
      "'reaction classic')",
    );

    final hits = await db
        .customSelect(
          'SELECT meme_id FROM meme_fts WHERE meme_fts MATCH ?',
          variables: [Variable('distracted*')],
        )
        .get();
    expect(hits.single.read<String>('meme_id'), 'm1');
  });

  test('data survives closing and reopening the same file', () async {
    final dir = await Directory.systemTemp.createTemp('meme_db_test');
    addTearDown(() => dir.delete(recursive: true));

    var db = AppDatabase.file(dir);
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'Reaction',
            normalizedName: 'reaction',
          ),
        );
    await db.close();

    db = AppDatabase.file(dir);
    addTearDown(db.close);
    final tags = await db.select(db.tags).get();
    expect(tags.single.name, 'Reaction');
  });

  test('meme_tags cascades on meme delete and enforces foreign keys', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    await db
        .into(db.memes)
        .insert(
          MemesCompanion.insert(
            id: 'm1',
            sha256: 'abc',
            mimeType: 'image/png',
            width: 1,
            height: 1,
            sizeBytes: 10,
            relativePath: 'originals/abc.png',
            thumbnailPath: 'thumbs/abc_t.png',
            sourceKind: 'clipboard',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(id: 't1', name: 'fun', normalizedName: 'fun'),
        );
    await db
        .into(db.memeTags)
        .insert(MemeTagsCompanion.insert(memeId: 'm1', tagId: 't1'));

    await (db.delete(db.memes)..where((m) => m.id.equals('m1'))).go();
    expect(await db.select(db.memeTags).get(), isEmpty);

    expect(
      () => db
          .into(db.memeTags)
          .insert(MemeTagsCompanion.insert(memeId: 'ghost', tagId: 't1')),
      throwsA(anything),
    );
  });

  test('sha256 and normalized tag name are unique', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    MemesCompanion meme(String id) => MemesCompanion.insert(
      id: id,
      sha256: 'same-hash',
      mimeType: 'image/png',
      width: 1,
      height: 1,
      sizeBytes: 10,
      relativePath: 'originals/x.png',
      thumbnailPath: 'thumbs/x_t.png',
      sourceKind: 'clipboard',
      createdAt: 0,
      updatedAt: 0,
    );

    await db.into(db.memes).insert(meme('m1'));
    expect(() => db.into(db.memes).insert(meme('m2')), throwsA(anything));

    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(id: 't1', name: 'Fun', normalizedName: 'fun'),
        );
    expect(
      () => db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(id: 't2', name: 'FUN', normalizedName: 'fun'),
          ),
      throwsA(anything),
    );
  });

  test('migrates a v1 file to v2, preserving rows and the FTS index', () async {
    final dir = await Directory.systemTemp.createTemp('meme_db_migration');
    addTearDown(() => dir.delete(recursive: true));

    final raw = NativeDatabase(File(p.join(dir.path, 'meme_library.db')));
    await raw.ensureOpen(_V1SchemaUser());
    for (final statement in _v1Schema) {
      await raw.runCustom(statement, const []);
    }
    await raw.runCustom(
      "INSERT INTO memes VALUES ('m1', 'abc', 'image/png', 1, 1, 10, "
      "'originals/abc.png', 'thumbs/abc_t.png', 'clipboard', NULL, "
      "'Distracted boyfriend', NULL, 0, 0)",
      const [],
    );
    await raw.runCustom(
      'INSERT INTO meme_fts (meme_id, title, notes, source_name, tag_names) '
      "VALUES ('m1', 'Distracted boyfriend', '', 'abc.png', '')",
      const [],
    );
    await raw.close();

    final db = AppDatabase.file(dir);
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);

    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
                )
                .get())
            .map((row) => row.read<String>('name'))
            .toSet();
    expect(names, containsAll(['sticker_packs', 'sticker_pack_items']));
    expect(names, contains('idx_sticker_pack_items_meme_id'));

    final memes = await db.select(db.memes).get();
    expect(memes.single.title, 'Distracted boyfriend');
    final hits = await db
        .customSelect(
          'SELECT meme_id FROM meme_fts WHERE meme_fts MATCH ?',
          variables: [Variable('distracted*')],
        )
        .get();
    expect(hits.single.read<String>('meme_id'), 'm1');

    await db
        .into(db.stickerPacks)
        .insert(
          StickerPacksCompanion.insert(
            id: 'p1',
            name: 'Pack',
            publisher: 'Meme Library',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.stickerPackItems)
        .insert(
          StickerPackItemsCompanion.insert(
            packId: 'p1',
            memeId: 'm1',
            position: 0,
          ),
        );

    await (db.delete(db.memes)..where((m) => m.id.equals('m1'))).go();
    expect(await db.select(db.stickerPackItems).get(), isEmpty);

    await (db.delete(db.stickerPacks)..where((sp) => sp.id.equals('p1'))).go();
    expect(await db.select(db.stickerPacks).get(), isEmpty);
  });
}
