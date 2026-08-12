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
    this.selectedIds = const {},
  });

  final List<Meme> items;

  /// Total matches for the active filter, excluding pending deletions.
  final int totalCount;

  final String searchText;
  final Set<String> tagIds;
  final bool loadingMore;

  /// Ids picked in bulk-select mode; always a subset of [items].
  final Set<String> selectedIds;

  bool get hasFilter => searchText.isNotEmpty || tagIds.isNotEmpty;

  bool get hasMore => items.length < totalCount;

  bool get selectionMode => selectedIds.isNotEmpty;

  /// Selected memes in grid order.
  List<Meme> get selectedItems => items
      .where((m) => selectedIds.contains(m.id))
      .toList(growable: false);

  LibraryState copyWith({
    List<Meme>? items,
    int? totalCount,
    String? searchText,
    Set<String>? tagIds,
    bool? loadingMore,
    Set<String>? selectedIds,
  }) {
    return LibraryState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      searchText: searchText ?? this.searchText,
      tagIds: tagIds ?? this.tagIds,
      loadingMore: loadingMore ?? this.loadingMore,
      selectedIds: selectedIds ?? this.selectedIds,
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
      // Selection never outlives visibility: reloads and filter changes
      // drop ids that are no longer on screen.
      selectedIds: base.selectedIds.isEmpty
          ? base.selectedIds
          : base.selectedIds.intersection({for (final m in visible) m.id}),
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

      // Re-read the state: a synchronous mutation (deleteManyWithUndo)
      // may have changed it while the query ran.
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

  /// Margin the deletion timers get past the advertised undo window, so
  /// an Undo tapped while the snackbar is still animating out can never
  /// arrive after the deletes committed.
  static const _undoGrace = Duration(seconds: 2);

  /// Hides [memes] immediately and deletes them after [undoWindow] unless
  /// [undoDeleteMany] is called first. Returns the hidden ids.
  List<String> deleteManyWithUndo(
    List<Meme> memes, {
    Duration undoWindow = const Duration(seconds: 5),
  }) {
    final current = state.value;
    if (current == null) return const [];

    // Captured now: the timers may fire after this notifier is disposed.
    final repository = ref.read(libraryRepositoryProvider);
    final ids = <String>[];
    for (final meme in memes) {
      if (_pendingDeletes.containsKey(meme.id)) continue;
      _pendingDeletes[meme.id] = Timer(undoWindow + _undoGrace, () async {
        _pendingDeletes.remove(meme.id);
        await repository.deleteMeme(meme.id);
      });
      ids.add(meme.id);
    }
    if (ids.isEmpty) return const [];

    final hidden = ids.toSet();
    state = AsyncData(
      current.copyWith(
        items: current.items
            .where((m) => !hidden.contains(m.id))
            .toList(growable: false),
        totalCount: current.totalCount - ids.length,
        selectedIds: current.selectedIds.difference(hidden),
      ),
    );
    return ids;
  }

  /// Cancels a batch of pending deletions and restores them in one reload.
  void undoDeleteMany(List<String> memeIds) {
    var restored = false;
    for (final id in memeIds) {
      final timer = _pendingDeletes.remove(id);
      if (timer != null) {
        timer.cancel();
        restored = true;
      }
    }
    if (restored) unawaited(_reload());
  }

  /// Toggles selection of a visible meme; selecting the first id enters
  /// selection mode, removing the last exits it.
  void toggleSelected(String memeId) {
    final current = state.value;
    if (current == null) return;
    if (!current.items.any((m) => m.id == memeId)) return;
    final ids = Set<String>.of(current.selectedIds);
    if (!ids.remove(memeId)) ids.add(memeId);
    state = AsyncData(current.copyWith(selectedIds: ids));
  }

  void clearSelection() {
    final current = state.value;
    if (current == null || current.selectedIds.isEmpty) return;
    state = AsyncData(current.copyWith(selectedIds: const {}));
  }

  /// Applies [tagName] to every selected meme and exits selection mode.
  /// Returns how many memes gained the tag.
  Future<int> addTagToSelected(String tagName) async {
    final current = state.value;
    if (current == null || current.selectedIds.isEmpty) return 0;
    final ids = [for (final meme in current.selectedItems) meme.id];
    clearSelection();
    return ref.read(libraryRepositoryProvider).addTagToMemes(ids, tagName);
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
