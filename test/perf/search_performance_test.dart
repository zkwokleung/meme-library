import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/data/library_repository.dart';
import 'package:meme_library/src/data/media_store.dart';
import 'package:meme_library/src/domain/library_query.dart';

void main() {
  const itemCount = 10000;
  late Directory root;
  late AppDatabase db;
  late DriftLibraryRepository repo;

  const words = [
    'distracted', 'boyfriend', 'fine', 'dog', 'cat', 'stonks', 'brain',
    'galaxy', 'drake', 'pointing', 'spiderman', 'confused', 'math', 'lady',
    'success', 'kid', 'grumpy', 'doge', 'wholesome', 'cursed', //
  ];

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('perf_test');
    db = AppDatabase.inMemory();
    repo = DriftLibraryRepository(db, MediaStore(root));

    // Seed 10k memes in one batch, then build the FTS index once.
    await db.batch((batch) {
      batch.insertAll(db.memes, [
        for (var i = 0; i < itemCount; i++)
          MemesCompanion.insert(
            id: 'meme-$i',
            sha256: 'hash-$i',
            mimeType: 'image/png',
            width: 640,
            height: 480,
            sizeBytes: 100000,
            relativePath: 'originals/hash-$i.png',
            thumbnailPath: 'thumbs/hash-${i}_t.jpg',
            sourceKind: 'clipboard',
            title: Value(
              '${words[i % words.length]} '
              '${words[(i ~/ words.length) % words.length]} $i',
            ),
            notes: Value('note ${words[(i * 7) % words.length]}'),
            createdAt: i,
            updatedAt: i,
          ),
      ]);
    });
    await repo.rebuildSearchIndex();
  });

  tearDownAll(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('representative searches return in under 150 ms at 10k items', () async {
    // Warm up sqlite page caches and the query planner.
    await repo.query(const LibraryQuery(searchText: 'warmup'));

    final samples = ['distracted', 'fine dog', 'stonks', 'success kid', 'gal'];
    for (final sample in samples) {
      final stopwatch = Stopwatch()..start();
      final page = await repo.query(LibraryQuery(searchText: sample));
      stopwatch.stop();

      expect(page.totalCount, greaterThan(0), reason: sample);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(150),
        reason: '"$sample" took ${stopwatch.elapsedMilliseconds} ms',
      );
    }
  });

  test('paged browsing queries stay fast at 10k items', () async {
    // Warm up statement preparation for this query shape.
    await repo.query(const LibraryQuery(limit: 60, offset: 0));

    final stopwatch = Stopwatch()..start();
    final page = await repo.query(const LibraryQuery(limit: 60, offset: 5000));
    stopwatch.stop();

    expect(page.items, hasLength(60));
    expect(stopwatch.elapsedMilliseconds, lessThan(150));
  });
}
