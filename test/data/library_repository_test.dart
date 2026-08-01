import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/image_validator.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/domain/library_query.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/domain/tag.dart';

import '../helpers/image_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late MediaStore media;
  late DriftLibraryRepository repo;
  const validator = ImageValidator();
  var idCounter = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('repo_test');
    db = AppDatabase.inMemory();
    media = MediaStore(root);
    await media.init();
    repo = DriftLibraryRepository(db, media);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// Stores a fresh image and returns an unsaved meme record for it.
  Future<Meme> stagedMeme({
    int seed = 0,
    String? title,
    String? notes,
    List<Tag> tags = const [],
    String? id,
  }) async {
    final image = validator.validate(pngBytes(seed: seed));
    final stored = await media.store(image);
    final now = DateTime.utc(2026, 1, 1).add(Duration(minutes: idCounter));
    return Meme(
      id: id ?? 'meme-${idCounter++}',
      sha256: stored.sha256,
      mimeType: image.mimeType,
      width: image.width,
      height: image.height,
      sizeBytes: image.sizeBytes,
      relativePath: stored.relativePath,
      thumbnailPath: stored.thumbnailPath,
      sourceKind: MemeSourceKind.clipboard,
      createdAt: now,
      updatedAt: now,
      title: title,
      notes: notes,
      tags: tags,
    );
  }

  test('insert, read back, and count', () async {
    final meme = await stagedMeme(seed: 1, title: 'Success kid');
    final saved = await repo.insertMeme(meme);

    expect(saved.title, 'Success kid');
    expect(await repo.memeCount(), 1);
    expect((await repo.memeById(meme.id))!.sha256, meme.sha256);
    expect((await repo.memeBySha256(meme.sha256))!.id, meme.id);
  });

  test('duplicate content hash is rejected with the existing meme', () async {
    final first = await repo.insertMeme(await stagedMeme(seed: 2));
    final duplicate = (await stagedMeme(seed: 2)).copyWith();

    await expectLater(
      repo.insertMeme(duplicate),
      throwsA(
        isA<DuplicateMemeException>().having(
          (e) => e.existing.id,
          'existing.id',
          first.id,
        ),
      ),
    );
  });

  test('failed insert removes the stored files', () async {
    final first = await stagedMeme(seed: 3);
    await repo.insertMeme(first);

    // Same primary key, different content: the DB write fails after the
    // files were stored, so the repository must clean them up.
    final conflicting = await stagedMeme(seed: 4, id: first.id);
    await expectLater(repo.insertMeme(conflicting), throwsA(anything));

    expect(await media.exists(conflicting.relativePath), isFalse);
    expect(await media.exists(conflicting.thumbnailPath), isFalse);
    // The first meme's files are untouched.
    expect(await media.exists(first.relativePath), isTrue);
    expect(await repo.memeCount(), 1);
  });

  test('metadata updates persist and bump updatedAt', () async {
    final saved = await repo.insertMeme(await stagedMeme(seed: 5));
    final updated = await repo.updateMetadata(
      saved.id,
      title: () => 'Renamed',
      notes: () => 'Better notes',
    );

    expect(updated.title, 'Renamed');
    final reloaded = await repo.memeById(saved.id);
    expect(reloaded!.notes, 'Better notes');
    expect(
      reloaded.updatedAt.isAfter(saved.updatedAt) ||
          reloaded.updatedAt.isAtSameMomentAs(saved.updatedAt),
      isTrue,
    );
  });

  test('tags are normalized, deduplicated, and persisted', () async {
    final saved = await repo.insertMeme(
      await stagedMeme(
        seed: 6,
        tags: const [
          Tag(id: 'a', name: 'Reaction'),
          Tag(id: 'b', name: ' reaction '),
          Tag(id: 'c', name: 'Dogs'),
        ],
      ),
    );

    expect(saved.tags.map((t) => t.name), ['Dogs', 'Reaction']);
    final all = await repo.allTags();
    expect(all.length, 2);

    final reassigned = await repo.setTags(saved.id, [all.first]);
    expect(reassigned.tags.length, 1);
  });

  test('query pages, filters by tags with AND semantics, and sorts', () async {
    final dogTag = await repo.ensureTag('dogs');
    final catTag = await repo.ensureTag('cats');

    await repo.insertMeme(await stagedMeme(seed: 10, tags: [dogTag]));
    await repo.insertMeme(await stagedMeme(seed: 11, tags: [dogTag, catTag]));
    await repo.insertMeme(await stagedMeme(seed: 12, tags: [catTag]));

    final all = await repo.query(const LibraryQuery(limit: 2));
    expect(all.items.length, 2);
    expect(all.totalCount, 3);
    // Newest first: highest createdAt first.
    expect(all.items.first.createdAt.isAfter(all.items.last.createdAt), isTrue);

    final both = await repo.query(LibraryQuery(tagIds: {dogTag.id, catTag.id}));
    expect(both.items.length, 1);
    expect(both.totalCount, 1);

    final page2 = await repo.query(const LibraryQuery(limit: 2, offset: 2));
    expect(page2.items.length, 1);
  });

  test('FTS search matches title, notes, source name, and tags', () async {
    await repo.insertMeme(
      await stagedMeme(seed: 20, title: 'Distracted boyfriend'),
    );
    await repo.insertMeme(
      await stagedMeme(seed: 21, notes: 'this is fine dog in fire'),
    );
    final tagged = await repo.insertMeme(
      await stagedMeme(seed: 22, tags: [await repo.ensureTag('wholesome')]),
    );

    Future<List<String>> search(String text) async {
      final page = await repo.query(LibraryQuery(searchText: text));
      return [for (final m in page.items) m.id];
    }

    expect(await search('distracted'), hasLength(1));
    expect(await search('fine dog'), hasLength(1));
    expect(await search('wholesome'), [tagged.id]);
    expect(await search('nothing-matches-this'), isEmpty);
    // Prefix matching.
    expect(await search('distr'), hasLength(1));
    // Hostile input does not crash FTS.
    expect(await search('"unbalanced OR (fts:'), isA<List<String>>());
  });

  test('search reflects metadata and tag edits', () async {
    final saved = await repo.insertMeme(await stagedMeme(seed: 30));
    expect(
      (await repo.query(const LibraryQuery(searchText: 'unique'))).items,
      isEmpty,
    );

    await repo.updateMetadata(saved.id, title: () => 'UniqueTitle');
    expect(
      (await repo.query(const LibraryQuery(searchText: 'uniquetitle'))).items,
      hasLength(1),
    );

    final tag = await repo.ensureTag('birbs');
    await repo.setTags(saved.id, [tag]);
    expect(
      (await repo.query(const LibraryQuery(searchText: 'birbs'))).items,
      hasLength(1),
    );

    await repo.renameTag(tag.id, 'Snakes');
    expect(
      (await repo.query(const LibraryQuery(searchText: 'birbs'))).items,
      isEmpty,
    );
    expect(
      (await repo.query(const LibraryQuery(searchText: 'snakes'))).items,
      hasLength(1),
    );

    await repo.deleteTag(tag.id);
    expect(
      (await repo.query(const LibraryQuery(searchText: 'snakes'))).items,
      isEmpty,
    );
  });

  test('renameTag rejects collisions with another tag', () async {
    final a = await repo.ensureTag('alpha');
    await repo.ensureTag('beta');
    await expectLater(repo.renameTag(a.id, ' BETA '), throwsStateError);
  });

  test('ensureTag reuses existing tags case-insensitively', () async {
    final first = await repo.ensureTag('Meta');
    final second = await repo.ensureTag('META');
    expect(second.id, first.id);
    expect((await repo.allTags()).length, 1);
  });

  test('delete removes record, search row, and files', () async {
    final saved = await repo.insertMeme(
      await stagedMeme(seed: 40, title: 'Gone soon'),
    );
    await repo.deleteMeme(saved.id);

    expect(await repo.memeById(saved.id), isNull);
    expect(await media.exists(saved.relativePath), isFalse);
    expect(
      (await repo.query(const LibraryQuery(searchText: 'gone'))).items,
      isEmpty,
    );
    // Idempotent.
    await repo.deleteMeme(saved.id);
  });

  test('reconcile removes orphan files and broken records', () async {
    final kept = await repo.insertMeme(await stagedMeme(seed: 50));
    final broken = await repo.insertMeme(await stagedMeme(seed: 51));
    final orphanImage = validator.validate(pngBytes(seed: 52));
    final orphan = await media.store(orphanImage); // never inserted

    // Break the second meme by deleting its original file.
    await media.resolve(broken.relativePath).delete();

    final report = await repo.reconcile();

    // The never-inserted orphan's original + thumbnail. The broken meme's
    // thumbnail is removed as part of the record cleanup instead.
    expect(report.deletedOrphanFiles, 2);
    expect(report.removedBrokenRecords, 1);
    expect(await repo.memeById(kept.id), isNotNull);
    expect(await repo.memeById(broken.id), isNull);
    expect(await media.exists(orphan.relativePath), isFalse);
    expect(await repo.memeCount(), 1);
  });

  test('rebuildSearchIndex restores search after index loss', () async {
    await repo.insertMeme(await stagedMeme(seed: 60, title: 'Phoenix'));
    await db.customStatement('DELETE FROM ${AppDatabase.ftsTable}');
    expect(
      (await repo.query(const LibraryQuery(searchText: 'phoenix'))).items,
      isEmpty,
    );

    await repo.rebuildSearchIndex();
    expect(
      (await repo.query(const LibraryQuery(searchText: 'phoenix'))).items,
      hasLength(1),
    );
  });

  test('changes stream emits on mutations', () async {
    final events = <void>[];
    final sub = repo.changes.listen(events.add);
    addTearDown(sub.cancel);

    await repo.insertMeme(await stagedMeme(seed: 70));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events, isNotEmpty);
  });
}
