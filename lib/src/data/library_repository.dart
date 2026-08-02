import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/library_query.dart';
import '../domain/meme.dart';
import '../domain/tag.dart' as domain;
import 'database/app_database.dart';
import 'media_store.dart';

class DuplicateMemeException implements Exception {
  const DuplicateMemeException(this.existing);

  /// The meme already holding this content hash.
  final Meme existing;
}

/// Reconciliation summary: what was cleaned up.
class ReconcileReport {
  const ReconcileReport({
    required this.deletedOrphanFiles,
    required this.removedBrokenRecords,
  });

  final int deletedOrphanFiles;
  final int removedBrokenRecords;
}

/// Persistence boundary for the meme library.
abstract interface class LibraryRepository {
  Future<Meme?> memeById(String id);
  Future<Meme?> memeBySha256(String sha256);
  Future<LibraryPage<Meme>> query(LibraryQuery query);

  /// Emits whenever library content changes.
  Stream<void> get changes;

  /// Inserts a meme whose files are already stored in the media store.
  ///
  /// The database write is transactional; if it fails the stored files are
  /// removed so no partial state survives. Throws [DuplicateMemeException]
  /// when the content hash already exists.
  Future<Meme> insertMeme(Meme meme);

  Future<Meme> updateMetadata(
    String id, {
    String? Function()? title,
    String? Function()? notes,
  });

  /// Replaces the tag set of a meme.
  Future<Meme> setTags(String id, List<domain.Tag> tags);

  /// Deletes the meme record and its stored files.
  Future<void> deleteMeme(String id);

  Future<List<domain.Tag>> allTags();

  /// Number of memes carrying each tag, keyed by tag id.
  Future<Map<String, int>> tagUsageCounts();

  /// Returns the existing tag with the same normalized name or creates it.
  Future<domain.Tag> ensureTag(String name);

  Future<domain.Tag> renameTag(String id, String newName);

  /// Removes a tag from every meme and deletes it.
  Future<void> deleteTag(String id);

  /// Replaces every meme, tag, and search row in one transaction.
  ///
  /// Used by restore: the incoming [memes] carry their tags. On failure
  /// the previous contents are untouched.
  Future<void> replaceAll(List<Meme> memes);

  /// Every media-root-relative path currently referenced by a record.
  Future<Set<String>> referencedMediaPaths();

  /// Removes files without records and records without files.
  Future<ReconcileReport> reconcile();

  /// Rebuilds the FTS index from the relational tables.
  Future<void> rebuildSearchIndex();

  Future<int> memeCount();
}

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._db, this._media, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final MediaStore _media;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<void> get changes =>
      _db.tableUpdates(TableUpdateQuery.any()).map((_) {});

  @override
  Future<Meme?> memeById(String id) async {
    final row = await (_db.select(
      _db.memes,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final tags = await _tagsFor([id]);
    return _toDomain(row, tags[id] ?? const []);
  }

  @override
  Future<Meme?> memeBySha256(String sha256) async {
    final row = await (_db.select(
      _db.memes,
    )..where((m) => m.sha256.equals(sha256))).getSingleOrNull();
    if (row == null) return null;
    final tags = await _tagsFor([row.id]);
    return _toDomain(row, tags[row.id] ?? const []);
  }

  @override
  Future<int> memeCount() async {
    final row = await _db
        .customSelect('SELECT COUNT(*) AS c FROM memes')
        .getSingle();
    return row.read<int>('c');
  }

  @override
  Future<LibraryPage<Meme>> query(LibraryQuery query) async {
    final where = <String>[];
    final args = <Variable<Object>>[];

    if (query.hasTextFilter) {
      final match = _ftsMatchExpression(query.searchText!);
      if (match == null) {
        return const LibraryPage(items: [], totalCount: 0);
      }
      where.add(
        'm.id IN (SELECT meme_id FROM ${AppDatabase.ftsTable} '
        'WHERE ${AppDatabase.ftsTable} MATCH ?)',
      );
      args.add(Variable(match));
    }

    if (query.tagIds.isNotEmpty) {
      final placeholders = List.filled(query.tagIds.length, '?').join(', ');
      where.add(
        'm.id IN (SELECT meme_id FROM meme_tags WHERE tag_id IN ($placeholders) '
        'GROUP BY meme_id HAVING COUNT(DISTINCT tag_id) = ?)',
      );
      args.addAll(query.tagIds.map(Variable.new));
      args.add(Variable(query.tagIds.length));
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final order = switch (query.sort) {
      MemeSort.newestFirst => 'ORDER BY m.created_at DESC, m.id DESC',
      MemeSort.oldestFirst => 'ORDER BY m.created_at ASC, m.id ASC',
    };

    final countRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM memes m $whereSql',
          variables: List.of(args),
        )
        .getSingle();
    final total = countRow.read<int>('c');

    final rows = await _db
        .customSelect(
          'SELECT m.* FROM memes m $whereSql $order LIMIT ? OFFSET ?',
          variables: [...args, Variable(query.limit), Variable(query.offset)],
        )
        .get();

    final memeRows = rows
        .map((row) => _db.memes.map(row.data))
        .toList(growable: false);
    final tagMap = await _tagsFor([for (final m in memeRows) m.id]);
    return LibraryPage(
      items: [
        for (final row in memeRows) _toDomain(row, tagMap[row.id] ?? const []),
      ],
      totalCount: total,
    );
  }

  @override
  Future<Meme> insertMeme(Meme meme) async {
    final existing = await memeBySha256(meme.sha256);
    if (existing != null) throw DuplicateMemeException(existing);

    try {
      return await _db.transaction(() async {
        await _db
            .into(_db.memes)
            .insert(
              MemesCompanion.insert(
                id: meme.id,
                sha256: meme.sha256,
                mimeType: meme.mimeType,
                width: meme.width,
                height: meme.height,
                sizeBytes: meme.sizeBytes,
                relativePath: meme.relativePath,
                thumbnailPath: meme.thumbnailPath,
                sourceKind: meme.sourceKind.name,
                sourceRef: Value(meme.sourceRef),
                title: Value(meme.title),
                notes: Value(meme.notes),
                createdAt: meme.createdAt.toUtc().millisecondsSinceEpoch,
                updatedAt: meme.updatedAt.toUtc().millisecondsSinceEpoch,
              ),
            );
        final tags = await _linkTags(meme.id, meme.tags);
        final stored = meme.copyWith(tags: tags);
        await _writeFtsRow(stored);
        return stored;
      });
    } catch (e) {
      // A concurrent import of identical content may have won the race
      // after our pre-check. The files are hash-keyed and shared with the
      // winner, so they must NOT be deleted in that case.
      final winner = await memeBySha256(meme.sha256);
      if (winner != null && winner.id != meme.id) {
        throw DuplicateMemeException(winner);
      }
      // The record failed to persist; remove the already-stored files so
      // the library never references half-imported content.
      await _media.delete(meme.relativePath, meme.thumbnailPath);
      rethrow;
    }
  }

  @override
  Future<Meme> updateMetadata(
    String id, {
    String? Function()? title,
    String? Function()? notes,
  }) {
    return _db.transaction(() async {
      final current = await _requireMeme(id);
      final updated = current.copyWith(
        title: title,
        notes: notes,
        updatedAt: _clock().toUtc(),
      );
      await (_db.update(_db.memes)..where((m) => m.id.equals(id))).write(
        MemesCompanion(
          title: Value(updated.title),
          notes: Value(updated.notes),
          updatedAt: Value(updated.updatedAt.millisecondsSinceEpoch),
        ),
      );
      await _writeFtsRow(updated);
      return updated;
    });
  }

  @override
  Future<Meme> setTags(String id, List<domain.Tag> tags) {
    return _db.transaction(() async {
      final current = await _requireMeme(id);
      await (_db.delete(
        _db.memeTags,
      )..where((mt) => mt.memeId.equals(id))).go();
      final linked = await _linkTags(id, tags);
      final updated = current.copyWith(
        tags: linked,
        updatedAt: _clock().toUtc(),
      );
      await (_db.update(_db.memes)..where((m) => m.id.equals(id))).write(
        MemesCompanion(
          updatedAt: Value(updated.updatedAt.millisecondsSinceEpoch),
        ),
      );
      await _writeFtsRow(updated);
      return updated;
    });
  }

  @override
  Future<void> deleteMeme(String id) async {
    final meme = await memeById(id);
    if (meme == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.memes)..where((m) => m.id.equals(id))).go();
      await _deleteFtsRow(id);
    });
    // File deletion after the record is gone; leftovers are orphans that
    // reconcile() removes.
    await _media.delete(meme.relativePath, meme.thumbnailPath);
  }

  @override
  Future<List<domain.Tag>> allTags() async {
    final rows = await (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.normalizedName)])).get();
    return [for (final row in rows) domain.Tag(id: row.id, name: row.name)];
  }

  @override
  Future<Map<String, int>> tagUsageCounts() async {
    final rows = await _db
        .customSelect(
          'SELECT tag_id, COUNT(*) AS c FROM meme_tags GROUP BY tag_id',
        )
        .get();
    return {
      for (final row in rows) row.read<String>('tag_id'): row.read<int>('c'),
    };
  }

  @override
  Future<domain.Tag> ensureTag(String name) => _db.transaction(() async {
    final tag = await _ensureTagInTransaction(name);
    return tag;
  });

  @override
  Future<domain.Tag> renameTag(String id, String newName) {
    return _db.transaction(() async {
      final normalized = domain.Tag.normalize(newName);
      if (normalized.isEmpty) {
        throw ArgumentError.value(newName, 'newName', 'Tag name is empty');
      }
      final clash =
          await (_db.select(_db.tags)..where(
                (t) =>
                    t.normalizedName.equals(normalized) & t.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (clash != null) {
        throw StateError('A tag named "$newName" already exists');
      }
      final updatedRows =
          await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
            TagsCompanion(
              name: Value(newName.trim()),
              normalizedName: Value(normalized),
            ),
          );
      if (updatedRows == 0) {
        throw StateError('The tag no longer exists');
      }
      await _refreshFtsForTag(id);
      return domain.Tag(id: id, name: newName.trim());
    });
  }

  @override
  Future<void> deleteTag(String id) {
    return _db.transaction(() async {
      final affected = await _memeIdsWithTag(id);
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      for (final memeId in affected) {
        final meme = await memeById(memeId);
        if (meme != null) await _writeFtsRow(meme);
      }
    });
  }

  @override
  Future<void> replaceAll(List<Meme> memes) {
    return _db.transaction(() async {
      await _db.delete(_db.memeTags).go();
      await _db.delete(_db.memes).go();
      await _db.delete(_db.tags).go();
      await _db.customStatement('DELETE FROM ${AppDatabase.ftsTable}');

      final insertedTags = <String>{};
      for (final meme in memes) {
        await _db
            .into(_db.memes)
            .insert(
              MemesCompanion.insert(
                id: meme.id,
                sha256: meme.sha256,
                mimeType: meme.mimeType,
                width: meme.width,
                height: meme.height,
                sizeBytes: meme.sizeBytes,
                relativePath: meme.relativePath,
                thumbnailPath: meme.thumbnailPath,
                sourceKind: meme.sourceKind.name,
                sourceRef: Value(meme.sourceRef),
                title: Value(meme.title),
                notes: Value(meme.notes),
                createdAt: meme.createdAt.toUtc().millisecondsSinceEpoch,
                updatedAt: meme.updatedAt.toUtc().millisecondsSinceEpoch,
              ),
            );
        for (final tag in meme.tags) {
          if (insertedTags.add(tag.id)) {
            await _db
                .into(_db.tags)
                .insert(
                  TagsCompanion.insert(
                    id: tag.id,
                    name: tag.name,
                    normalizedName: tag.normalized,
                  ),
                );
          }
          await _db
              .into(_db.memeTags)
              .insert(MemeTagsCompanion.insert(memeId: meme.id, tagId: tag.id));
        }
        await _writeFtsRow(meme);
      }
    });
  }

  @override
  Future<Set<String>> referencedMediaPaths() async {
    final rows = await _db.select(_db.memes).get();
    return {
      for (final row in rows) ...[row.relativePath, row.thumbnailPath],
    };
  }

  @override
  Future<ReconcileReport> reconcile() async {
    // Staging is deliberately NOT cleared here: an import may be mid-write
    // in staging while reconciliation runs. Startup clears staging instead.
    final rows = await _db.select(_db.memes).get();
    final referenced = <String>{};
    var removedRecords = 0;

    for (final row in rows) {
      final originalExists = await _media.exists(row.relativePath);
      if (!originalExists) {
        // A meme without its original image is unrecoverable locally.
        await _db.transaction(() async {
          await (_db.delete(_db.memes)..where((m) => m.id.equals(row.id))).go();
          await _deleteFtsRow(row.id);
        });
        await _media.delete(row.relativePath, row.thumbnailPath);
        removedRecords++;
      } else {
        referenced.add(row.relativePath);
        referenced.add(row.thumbnailPath);
      }
    }

    var deletedFiles = 0;
    for (final path in await _media.listManagedFiles()) {
      if (!referenced.contains(path)) {
        await _media.resolve(path).delete();
        deletedFiles++;
      }
    }

    return ReconcileReport(
      deletedOrphanFiles: deletedFiles,
      removedBrokenRecords: removedRecords,
    );
  }

  @override
  Future<void> rebuildSearchIndex() async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM ${AppDatabase.ftsTable}');
      final rows = await _db.select(_db.memes).get();
      final tagMap = await _tagsFor([for (final row in rows) row.id]);
      for (final row in rows) {
        await _writeFtsRow(_toDomain(row, tagMap[row.id] ?? const []));
      }
    });
  }

  // -- internals ----------------------------------------------------------

  Future<Meme> _requireMeme(String id) async {
    final meme = await memeById(id);
    if (meme == null) {
      throw StateError('Meme $id does not exist');
    }
    return meme;
  }

  /// Ensures all [tags] exist and are linked to [memeId]. Returns the
  /// canonical tags (existing ids win over incoming ids).
  Future<List<domain.Tag>> _linkTags(
    String memeId,
    List<domain.Tag> tags,
  ) async {
    final linked = <domain.Tag>[];
    final seen = <String>{};
    for (final tag in tags) {
      final canonical = await _ensureTagInTransaction(tag.name);
      if (!seen.add(canonical.id)) continue;
      await _db
          .into(_db.memeTags)
          .insert(
            MemeTagsCompanion.insert(memeId: memeId, tagId: canonical.id),
            mode: InsertMode.insertOrIgnore,
          );
      linked.add(canonical);
    }
    linked.sort((a, b) => a.normalized.compareTo(b.normalized));
    return linked;
  }

  Future<domain.Tag> _ensureTagInTransaction(String name) async {
    final normalized = domain.Tag.normalize(name);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name is empty');
    }
    final existing = await (_db.select(
      _db.tags,
    )..where((t) => t.normalizedName.equals(normalized))).getSingleOrNull();
    if (existing != null) {
      return domain.Tag(id: existing.id, name: existing.name);
    }
    final tag = domain.Tag(id: _uuid.v4(), name: name.trim());
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: tag.id,
            name: tag.name,
            normalizedName: normalized,
          ),
        );
    return tag;
  }

  /// Chunked to stay far below SQLite's bound-variable limit even when
  /// called with every meme id (e.g. from [rebuildSearchIndex]).
  Future<Map<String, List<domain.Tag>>> _tagsFor(List<String> memeIds) async {
    if (memeIds.isEmpty) return const {};
    const chunkSize = 500;
    final result = <String, List<domain.Tag>>{};
    for (var start = 0; start < memeIds.length; start += chunkSize) {
      final chunk = memeIds.sublist(
        start,
        start + chunkSize > memeIds.length ? memeIds.length : start + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT mt.meme_id AS meme_id, t.id AS id, t.name AS name '
            'FROM meme_tags mt JOIN tags t ON t.id = mt.tag_id '
            'WHERE mt.meme_id IN ($placeholders) '
            'ORDER BY t.normalized_name',
            variables: [for (final id in chunk) Variable(id)],
          )
          .get();
      for (final row in rows) {
        result
            .putIfAbsent(row.read<String>('meme_id'), () => [])
            .add(
              domain.Tag(
                id: row.read<String>('id'),
                name: row.read<String>('name'),
              ),
            );
      }
    }
    return result;
  }

  Future<List<String>> _memeIdsWithTag(String tagId) async {
    final rows = await (_db.select(
      _db.memeTags,
    )..where((mt) => mt.tagId.equals(tagId))).get();
    return [for (final row in rows) row.memeId];
  }

  Future<void> _refreshFtsForTag(String tagId) async {
    for (final memeId in await _memeIdsWithTag(tagId)) {
      final meme = await memeById(memeId);
      if (meme != null) await _writeFtsRow(meme);
    }
  }

  Future<void> _writeFtsRow(Meme meme) async {
    await _deleteFtsRow(meme.id);
    await _db.customInsert(
      'INSERT INTO ${AppDatabase.ftsTable} '
      '(meme_id, title, notes, source_name, tag_names) '
      'VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable(meme.id),
        Variable(meme.title ?? ''),
        Variable(meme.notes ?? ''),
        Variable(meme.sourceRef ?? ''),
        Variable(meme.tags.map((t) => t.name).join(' ')),
      ],
      updates: {_db.memes},
    );
  }

  Future<void> _deleteFtsRow(String memeId) async {
    await _db.customUpdate(
      'DELETE FROM ${AppDatabase.ftsTable} WHERE meme_id = ?',
      variables: [Variable(memeId)],
      updates: {_db.memes},
      updateKind: UpdateKind.delete,
    );
  }

  /// Builds a safe FTS5 prefix-match expression from user text, or `null`
  /// when the text contains no indexable tokens (punctuation-only tokens
  /// would otherwise produce empty phrases that FTS5 rejects).
  String? _ftsMatchExpression(String raw) {
    final tokens = raw
        .replaceAll(RegExp('["*]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t))
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.map((t) => '"$t"*').join(' ');
  }

  Meme _toDomain(MemeRow row, List<domain.Tag> tags) => Meme(
    id: row.id,
    sha256: row.sha256,
    mimeType: row.mimeType,
    width: row.width,
    height: row.height,
    sizeBytes: row.sizeBytes,
    relativePath: row.relativePath,
    thumbnailPath: row.thumbnailPath,
    sourceKind: MemeSourceKind.values.byName(row.sourceKind),
    sourceRef: row.sourceRef,
    title: row.title,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    tags: tags,
  );
}
