import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Saved memes. Timestamps are UTC epoch milliseconds.
@DataClassName('MemeRow')
class Memes extends Table {
  TextColumn get id => text()();
  TextColumn get sha256 => text().unique()();
  TextColumn get mimeType => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get sizeBytes => integer()();
  TextColumn get relativePath => text()();
  TextColumn get thumbnailPath => text()();
  TextColumn get sourceKind => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MemeTagRow')
class MemeTags extends Table {
  TextColumn get memeId =>
      text().references(Memes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {memeId, tagId};
}

/// Versioned local metadata store.
///
/// Besides the Drift-managed tables this owns a `meme_fts` FTS5 table that
/// indexes title, notes, source name, and tag names per meme. FTS rows are
/// maintained by the repository inside the same transactions that mutate
/// the indexed data.
@DriftDatabase(tables: [Memes, Tags, MemeTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the database file at [directory]/meme_library.db.
  factory AppDatabase.file(Directory directory) => AppDatabase(
    NativeDatabase.createInBackground(
      File(p.join(directory.path, 'meme_library.db')),
    ),
  );

  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  static const ftsTable = 'meme_fts';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE VIRTUAL TABLE $ftsTable USING fts5('
        'meme_id UNINDEXED, title, notes, source_name, tag_names, '
        "tokenize='unicode61 remove_diacritics 2')",
      );
      await customStatement(
        'CREATE INDEX idx_memes_created_at ON memes (created_at DESC)',
      );
      await customStatement(
        'CREATE INDEX idx_meme_tags_tag_id ON meme_tags (tag_id)',
      );
    },
    onUpgrade: (m, from, to) async {
      // Future schema versions add their steps here; each step must be
      // covered by a migration test before shipping.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
