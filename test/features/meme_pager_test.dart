import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/data/database/app_database.dart';
import 'package:meme_library/src/features/library/meme_pager.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late int updates;

  setUp(() async {
    harness = await TestHarness.create();
    updates = 0;
  });

  tearDown(() => harness.dispose());

  MemePager pager({int pageSize = 2, Set<String> Function()? hiddenIds}) =>
      MemePager(
        repository: harness.repository,
        onUpdate: () => updates++,
        pageSize: pageSize,
        hiddenIds: hiddenIds,
      );

  Future<void> insertMeme(String id, int createdAt) => harness.database
      .into(harness.database.memes)
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
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  Future<void> insertMemes(int count, {int startAt = 0}) async {
    for (var i = 0; i < count; i++) {
      await insertMeme('m${startAt + i}', startAt + i);
    }
  }

  test('pages newest-first until the count is exhausted', () async {
    await insertMemes(5);
    final subject = pager();

    expect(subject.initialized, isFalse);
    await subject.refresh();
    expect(subject.initialized, isTrue);
    expect(subject.items.map((m) => m.id), ['m4', 'm3']);
    expect(subject.totalCount, 5);
    expect(subject.hasMore, isTrue);

    await subject.loadMore();
    await subject.loadMore();
    expect(subject.items, hasLength(5));
    expect(subject.hasMore, isFalse);

    // Saturated: another call issues no query and changes nothing.
    final updatesBefore = updates;
    await subject.loadMore();
    expect(updates, updatesBefore);
  });

  test('a non-empty page of duplicates terminates paging', () async {
    await insertMemes(4);
    final subject = pager();
    await subject.refresh();
    expect(subject.items.map((m) => m.id), ['m3', 'm2']);
    expect(subject.totalCount, 4);

    // Newer memes land before the loaded window, so the next offset page
    // returns exactly the items already on screen.
    await insertMemes(2, startAt: 4);
    await subject.loadMore();

    expect(subject.items, hasLength(2));
    expect(subject.hasMore, isFalse);
  });

  test('hidden ids are excluded and the count adjusted', () async {
    await insertMemes(3);
    final hidden = <String>{'m2'};
    final subject = pager(pageSize: 10, hiddenIds: () => hidden);

    await subject.refresh();
    expect(subject.items.map((m) => m.id), ['m1', 'm0']);
    expect(subject.totalCount, 2);
  });

  test('search is debounced and no-ops on unchanged text', () async {
    await insertMemes(3);
    final subject = pager(pageSize: 10);
    await subject.refresh();
    final updatesBefore = updates;

    subject.setSearchText('  ');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(updates, updatesBefore);
    expect(subject.items, hasLength(3));

    subject.setSearchText('zzz');
    // The previous grid stays until the new page lands.
    expect(subject.items, hasLength(3));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(subject.searchText, 'zzz');
    expect(subject.items, isEmpty);
    expect(subject.initialized, isTrue);
  });

  test('refresh keeps at least minimumItems loaded', () async {
    await insertMemes(5);
    final subject = pager();
    await subject.refresh();
    await subject.loadMore();
    expect(subject.items, hasLength(4));

    await subject.refresh(minimumItems: subject.items.length);
    expect(subject.items, hasLength(4));
  });
}
