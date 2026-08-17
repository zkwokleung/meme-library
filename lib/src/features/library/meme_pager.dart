import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/library_repository.dart';
import '../../domain/library_query.dart';
import '../../domain/meme.dart';

/// Shared search and offset-paging core over [LibraryRepository.query].
///
/// Owns the concurrency-sensitive parts — search debounce, generation
/// guard, id-dedupe on append, and count clamping — so the library grid
/// and the sticker meme picker cannot drift apart. Presentation state
/// stays with the caller, which is notified through [onUpdate].
class MemePager {
  MemePager({
    required LibraryRepository repository,
    required VoidCallback onUpdate,
    this.pageSize = 60,
    Set<String> Function()? hiddenIds,
  }) : _repository = repository,
       _onUpdate = onUpdate,
       _hiddenIds = hiddenIds ?? _noHidden;

  static Set<String> _noHidden() => const {};

  final LibraryRepository _repository;
  final VoidCallback _onUpdate;
  final int pageSize;

  /// Ids to exclude from results (e.g. memes pending delete-with-undo),
  /// re-read on every fetch.
  final Set<String> Function() _hiddenIds;

  List<Meme> _items = const [];
  var _totalCount = 0;
  var _searchText = '';
  Set<String> _tagIds = const {};
  var _initialized = false;
  var _loadingMore = false;
  var _generation = 0;
  Timer? _searchDebounce;

  List<Meme> get items => _items;
  int get totalCount => _totalCount;
  bool get hasMore => _items.length < _totalCount;
  String get searchText => _searchText;
  Set<String> get tagIds => _tagIds;
  bool get loadingMore => _loadingMore;

  /// False until the first [refresh] lands; callers show a loading state
  /// rather than an empty-results message.
  bool get initialized => _initialized;

  void dispose() => _searchDebounce?.cancel();

  /// Debounced free-text search. The previous items stay visible until the
  /// new first page lands, so callers never flash an empty grid.
  void setSearchText(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final trimmed = text.trim();
      if (trimmed == _searchText) return;
      _searchText = trimmed;
      // Keep whatever is on screen if the reload fails.
      unawaited(refresh().catchError((_) => false));
    });
  }

  /// Replaces the query outright (no debounce) without fetching; callers
  /// follow up with [refresh].
  void setQuery({String? searchText, Set<String>? tagIds}) {
    _searchDebounce?.cancel();
    if (searchText != null) _searchText = searchText.trim();
    if (tagIds != null) _tagIds = tagIds;
  }

  /// Reloads the current query from offset zero, keeping at least
  /// [minimumItems] loaded so a reload preserves the scroll window.
  /// Returns false when a newer query superseded this one.
  Future<bool> refresh({int? minimumItems}) async {
    // A pending debounce must not re-apply old text over this reload.
    _searchDebounce?.cancel();
    final generation = ++_generation;
    final limit = minimumItems == null || minimumItems < pageSize
        ? pageSize
        : minimumItems;
    final page = await _repository.query(
      LibraryQuery(
        searchText: _searchText.isEmpty ? null : _searchText,
        tagIds: _tagIds,
        limit: limit,
      ),
    );
    if (generation != _generation) return false;

    final hidden = _hiddenIds();
    final visible = page.items
        .where((m) => !hidden.contains(m.id))
        .toList(growable: false);
    _items = visible;
    _totalCount = page.totalCount - (page.items.length - visible.length);
    _initialized = true;
    _loadingMore = false;
    _onUpdate();
    return true;
  }

  Future<void> loadMore() async {
    if (!_initialized || _loadingMore || !hasMore) return;
    _loadingMore = true;
    _onUpdate();
    // Participate in the current generation without claiming a new one: a
    // query change mid-flight must win, not be cancelled by paging.
    final generation = _generation;

    try {
      final page = await _repository.query(
        LibraryQuery(
          searchText: _searchText.isEmpty ? null : _searchText,
          tagIds: _tagIds,
          limit: pageSize,
          offset: _items.length,
        ),
      );
      if (generation != _generation) return;

      final hidden = _hiddenIds();
      final incoming = page.items
          .where(
            (m) =>
                !hidden.contains(m.id) &&
                !_items.any((existing) => existing.id == m.id),
          )
          .toList(growable: false);
      _items = [..._items, ...incoming];
      // A page that adds nothing means the count and reality disagree
      // (hidden rows, concurrent inserts or deletes shifting offsets);
      // stop paging rather than re-issue the same query forever.
      _totalCount = incoming.isEmpty
          ? _items.length
          : (page.totalCount - hidden.length).clamp(_items.length, 1 << 30);
      _onUpdate();
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _onUpdate();
      }
    }
  }
}
