import 'package:meta/meta.dart';

/// Sort order for library listings.
enum MemeSort { newestFirst, oldestFirst }

/// A paged, filtered library request.
@immutable
class LibraryQuery {
  const LibraryQuery({
    this.searchText,
    this.tagIds = const {},
    this.sort = MemeSort.newestFirst,
    this.limit = 60,
    this.offset = 0,
  }) : assert(limit > 0, 'limit must be positive'),
       assert(offset >= 0, 'offset must not be negative');

  /// Free-text search over title, notes, source name, and tag names.
  /// `null` or blank means no text filter.
  final String? searchText;

  /// Memes must carry every tag in this set (AND semantics).
  final Set<String> tagIds;

  final MemeSort sort;
  final int limit;
  final int offset;

  bool get hasTextFilter => searchText != null && searchText!.trim().isNotEmpty;

  LibraryQuery copyWith({
    String? Function()? searchText,
    Set<String>? tagIds,
    MemeSort? sort,
    int? limit,
    int? offset,
  }) {
    return LibraryQuery(
      searchText: searchText != null ? searchText() : this.searchText,
      tagIds: tagIds ?? this.tagIds,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.searchText == searchText &&
      other.sort == sort &&
      other.limit == limit &&
      other.offset == offset &&
      other.tagIds.length == tagIds.length &&
      other.tagIds.containsAll(tagIds);

  @override
  int get hashCode => Object.hash(
    searchText,
    sort,
    limit,
    offset,
    Object.hashAllUnordered(tagIds),
  );
}

/// One page of results plus the total row count for the same filter.
@immutable
class LibraryPage<T> {
  const LibraryPage({required this.items, required this.totalCount});

  final List<T> items;
  final int totalCount;

  bool get isEmpty => items.isEmpty;
}
