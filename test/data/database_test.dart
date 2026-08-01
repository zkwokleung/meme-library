import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';

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

    expect(names, containsAll(['memes', 'tags', 'meme_tags', 'meme_fts']));
    expect(names, contains('idx_memes_created_at'));
    expect(names, contains('idx_meme_tags_tag_id'));

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
}
