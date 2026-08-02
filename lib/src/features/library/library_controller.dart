import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/library_query.dart';
import '../../domain/meme.dart';
import '../../domain/tag.dart';

/// Immutable view state for the library grid.
class LibraryState {
  const LibraryState({
    this.items = const [],
    this.totalCount = 0,
    this.searchText = '',
    this.tagIds = const {},
    this.loadingMore = false,
  });

  final List<Meme> items;

  /// Total matches for the active filter, excluding pending deletions.
  final int totalCount;

  final String searchText;
  final Set<String> tagIds;
  final bool loadingMore;

  bool get hasFilter => searchText.isNotEmpty || tagIds.isNotEmpty;

  bool get hasMore => items.length < totalCount;

  LibraryState copyWith({
    List<Meme>? items,
    int? totalCount,
    String? searchText,
    Set<String>? tagIds,
    bool? loadingMore,
  }) {
    return LibraryState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      searchText: searchText ?? this.searchText,
      tagIds: tagIds ?? this.tagIds,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Drives the library grid: paging, filtering, and delete-with-undo.
class LibraryController extends AsyncNotifier<LibraryState> {
  static const pageSize = 60;

  /// Memes hidden from view and scheduled for deletion.
  final _pendingDeletes = <String, Timer>{};
  Timer? _searchDebounce;
  Timer? _changeDebounce;
  int _generation = 0;

  @override
  Future<LibraryState> build() async {
    final repository = ref.watch(libraryRepositoryProvider);
    final subscription = repository.changes.listen((_) {
      _changeDebounce?.cancel();
      _changeDebounce = Timer(const Duration(milliseconds: 100), () {
        unawaited(_reload());
      });
    });
    ref.onDispose(() {
      subscription.cancel();
      _searchDebounce?.cancel();
      _changeDebounce?.cancel();
      // The UI already reported these memes as deleted; commit rather
      // than silently resurrect them on next launch.
      for (final entry in _pendingDeletes.entries) {
        entry.value.cancel();
        unawaited(repository.deleteMeme(entry.key));
      }
      _pendingDeletes.clear();
    });
    return _fetch(const LibraryState());
  }

  Future<LibraryState> _fetch(LibraryState base, {int? minimumItems}) async {
    final repository = ref.read(libraryRepositoryProvider);
    final limit = minimumItems == null || minimumItems < pageSize
        ? pageSize
        : minimumItems;
    final page = await repository.query(
      LibraryQuery(
        searchText: base.searchText.isEmpty ? null : base.searchText,
        tagIds: base.tagIds,
        limit: limit,
      ),
    );
    final visible = page.items
        .where((m) => !_pendingDeletes.containsKey(m.id))
        .toList(growable: false);
    return base.copyWith(
      items: visible,
      totalCount: page.totalCount - (page.items.length - visible.length),
      loadingMore: false,
    );
  }

  /// Re-runs the current query, keeping the scroll window size (plus
  /// room for hidden pending deletions).
  Future<void> _reload() async {
    final current = state.value;
    if (current == null) return;
    final generation = ++_generation;
    try {
      final next = await _fetch(
        current,
        minimumItems: current.items.length + _pendingDeletes.length,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(next);
    } catch (e, stackTrace) {
      // Keep showing the previous data; surface the error only when
      // there is nothing to show.
      if (ref.mounted && state.value == null) {
        state = AsyncError(e, stackTrace);
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    // Participate in the current generation without claiming a new one:
    // a filter change mid-flight must win, not be cancelled by paging.
    final generation = _generation;

    try {
      final page = await ref
          .read(libraryRepositoryProvider)
          .query(
            LibraryQuery(
              searchText: current.searchText.isEmpty
                  ? null
                  : current.searchText,
              tagIds: current.tagIds,
              limit: pageSize,
              offset: current.items.length,
            ),
          );
      if (!ref.mounted || generation != _generation) return;

      // Re-read the state: a synchronous mutation (deleteWithUndo) may
      // have changed it while the query ran.
      final latest = state.value;
      if (latest == null) return;
      final incoming = page.items.where(
        (m) =>
            !_pendingDeletes.containsKey(m.id) &&
            !latest.items.any((existing) => existing.id == m.id),
      );
      final items = [...latest.items, ...incoming];
      // An empty page means the count and reality disagree (e.g. hidden
      // pending deletions); stop paging rather than spin forever.
      final total = page.items.isEmpty
          ? items.length
          : (page.totalCount - _pendingDeletes.length).clamp(
              items.length,
              1 << 30,
            );
      state = AsyncData(
        latest.copyWith(items: items, totalCount: total, loadingMore: false),
      );
    } catch (_) {
      if (!ref.mounted) return;
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(loadingMore: false));
      }
    }
  }

  /// Debounced free-text search.
  void setSearchText(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final current = state.value;
      if (current == null || current.searchText == text.trim()) return;
      unawaited(_apply(current.copyWith(searchText: text.trim())));
    });
  }

  Future<void> toggleTag(String tagId) async {
    final current = state.value;
    if (current == null) return;
    final tagIds = Set<String>.of(current.tagIds);
    if (!tagIds.remove(tagId)) tagIds.add(tagId);
    await _apply(current.copyWith(tagIds: tagIds));
  }

  Future<void> clearFilters() async {
    final current = state.value;
    if (current == null) return;
    await _apply(const LibraryState());
  }

  /// Applies a new filter. The previous grid stays visible while the new
  /// results load, avoiding a loading flash on every keystroke.
  Future<void> _apply(LibraryState base) async {
    // A stale search debounce must not re-apply old text over this change.
    _searchDebounce?.cancel();
    final generation = ++_generation;
    try {
      final next = await _fetch(base);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(next);
    } catch (e, stackTrace) {
      if (ref.mounted && state.value == null) {
        state = AsyncError(e, stackTrace);
      }
    }
  }

  /// Hides the meme immediately and deletes it after [undoWindow] unless
  /// [undoDelete] is called first.
  void deleteWithUndo(
    Meme meme, {
    Duration undoWindow = const Duration(seconds: 5),
  }) {
    final current = state.value;
    if (current == null || _pendingDeletes.containsKey(meme.id)) return;

    // Captured now: the timer may fire after this notifier is disposed.
    final repository = ref.read(libraryRepositoryProvider);
    _pendingDeletes[meme.id] = Timer(undoWindow, () async {
      _pendingDeletes.remove(meme.id);
      await repository.deleteMeme(meme.id);
    });
    state = AsyncData(
      current.copyWith(
        items: current.items
            .where((m) => m.id != meme.id)
            .toList(growable: false),
        totalCount: current.totalCount - 1,
      ),
    );
  }

  /// Cancels a pending deletion and restores the meme in place.
  void undoDelete(String memeId) {
    final timer = _pendingDeletes.remove(memeId);
    if (timer == null) return;
    timer.cancel();
    unawaited(_reload());
  }

  /// Runs any pending deletions immediately (e.g. before a backup, so an
  /// export never contains memes the user already deleted).
  Future<void> flushPendingDeletes() async {
    final repository = ref.read(libraryRepositoryProvider);
    final ids = _pendingDeletes.keys.toList(growable: false);
    for (final id in ids) {
      _pendingDeletes.remove(id)?.cancel();
      await repository.deleteMeme(id);
    }
  }
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, LibraryState>(
      LibraryController.new,
    );

/// All tags with usage counts, refreshed on any library change.
final tagsProvider = StreamProvider<List<(Tag, int)>>((ref) async* {
  final repository = ref.watch(libraryRepositoryProvider);

  Future<List<(Tag, int)>> load() async {
    final tags = await repository.allTags();
    final counts = await repository.tagUsageCounts();
    return [for (final tag in tags) (tag, counts[tag.id] ?? 0)];
  }

  yield await load();
  await for (final _ in repository.changes) {
    yield await load();
  }
});
