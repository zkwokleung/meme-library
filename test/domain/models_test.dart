import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/domain/library_query.dart';
import 'package:meme_library/src/domain/meme.dart';
import 'package:meme_library/src/domain/tag.dart';

Meme _sampleMeme() => Meme(
  id: 'm1',
  sha256: 'deadbeef',
  mimeType: 'image/png',
  width: 640,
  height: 480,
  sizeBytes: 12345,
  relativePath: 'originals/deadbeef.png',
  thumbnailPath: 'thumbs/deadbeef_t.jpg',
  sourceKind: MemeSourceKind.url,
  sourceRef: 'https://example.com/meme.png',
  title: 'Fine dog',
  notes: 'this is fine',
  createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  updatedAt: DateTime.utc(2026, 1, 3),
  tags: const [Tag(id: 't1', name: 'Reaction')],
);

void main() {
  group('Tag', () {
    test('normalizes case and whitespace', () {
      expect(Tag.normalize('  Fun   Stuff '), 'fun stuff');
      expect(const Tag(id: 't', name: ' FUN ').normalized, 'fun');
    });

    test('equality and json round trip', () {
      const tag = Tag(id: 't1', name: 'Reaction');
      expect(tag, const Tag(id: 't1', name: 'Reaction'));
      expect(tag.hashCode, const Tag(id: 't1', name: 'Reaction').hashCode);
      expect(Tag.fromJson(tag.toJson()), tag);
    });
  });

  group('Meme', () {
    test('equality', () {
      expect(_sampleMeme(), _sampleMeme());
      expect(_sampleMeme().hashCode, _sampleMeme().hashCode);
      expect(
        _sampleMeme().copyWith(title: () => 'Other'),
        isNot(_sampleMeme()),
      );
    });

    test('json round trip preserves every field', () {
      final meme = _sampleMeme();
      expect(Meme.fromJson(meme.toJson()), meme);
    });

    test('copyWith can clear nullable fields', () {
      final cleared = _sampleMeme().copyWith(
        title: () => null,
        notes: () => null,
      );
      expect(cleared.title, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.sha256, _sampleMeme().sha256);
    });
  });

  group('LibraryQuery', () {
    test('detects text filter', () {
      expect(const LibraryQuery().hasTextFilter, isFalse);
      expect(const LibraryQuery(searchText: '  ').hasTextFilter, isFalse);
      expect(const LibraryQuery(searchText: 'dog').hasTextFilter, isTrue);
    });

    test('equality ignores tag id order', () {
      expect(
        const LibraryQuery(tagIds: {'a', 'b'}),
        const LibraryQuery(tagIds: {'b', 'a'}),
      );
    });

    test('copyWith replaces paging values', () {
      const query = LibraryQuery(limit: 10, offset: 0);
      final next = query.copyWith(offset: 10);
      expect(next.offset, 10);
      expect(next.limit, 10);
    });
  });
}
