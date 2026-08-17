import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meme.dart';
import '../../domain/tag.dart';
import 'meme_pager.dart';

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
  List<Meme> get selectedItems =>
      items.where((m) => selectedIds.contains(m.id)).toList(growable: false);

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

  /// Ids inside the delete-with-undo window; other meme views (the sticker
  /// picker) exclude these so a doomed meme cannot be acted on.
  Set<String> get pendingDeleteIds => Set.unmodifiable(_pendingDeletes.keys);
  Timer? _changeDebounce;
  late MemePager _pager;

  @override
  Future<LibraryState> build() async {
    final repository = ref.watch(libraryRepositoryProvider);
    _pager = MemePager(
      repository: repository,
      onUpdate: _publish,
      pageSize: pageSize,
      hiddenIds: () => _pendingDeletes.keys.toSet(),
    );
    final subscription = repository.changes.listen((_) {
      _changeDebounce?.cancel();
      _changeDebounce = Timer(const Duration(milliseconds: 100), () {
        unawaited(_reload());
      });
    });
    ref.onDispose(() {
      subscription.cancel();
      _changeDebounce?.cancel();
      _pager.dispose();
      // The UI already reported these memes as deleted; commit rather
      // than silently resurrect them on next launch.
      for (final entry in _pendingDeletes.entries) {
        entry.value.cancel();
        unawaited(repository.deleteMeme(entry.key));
      }
      _pendingDeletes.clear();
    });
    await _pager.refresh();
    return _snapshot(selectedIds: const {});
  }

  /// The pager filters pending deletes at fetch time; the second filter
  /// here covers memes hidden by [deleteManyWithUndo] after their page was
  /// already loaded.
  LibraryState _snapshot({required Set<String> selectedIds}) {
    final visible = _pager.items
        .where((m) => !_pendingDeletes.containsKey(m.id))
        .toList(growable: false);
    final hiddenInPage = _pager.items.length - visible.length;
    return LibraryState(
      items: visible,
      totalCount: _pager.totalCount - hiddenInPage,
      searchText: _pager.searchText,
      tagIds: _pager.tagIds,
      loadingMore: _pager.loadingMore,
      // Selection never outlives visibility: reloads and filter changes
      // drop ids that are no longer on screen.
      selectedIds: selectedIds.isEmpty
          ? selectedIds
          : selectedIds.intersection({for (final m in visible) m.id}),
    );
  }

  void _publish() {
    if (!ref.mounted) return;
    state = AsyncData(
      _snapshot(selectedIds: state.value?.selectedIds ?? const {}),
    );
  }

  /// Re-runs the current query, keeping the scroll window size (plus
  /// room for hidden pending deletions).
  Future<void> _reload() async {
    final current = state.value;
    if (current == null) return;
    try {
      await _pager.refresh(
        minimumItems: current.items.length + _pendingDeletes.length,
      );
    } catch (e, stackTrace) {
      // Keep showing the previous data; surface the error only when
      // there is nothing to show.
      if (ref.mounted && state.value == null) {
        state = AsyncError(e, stackTrace);
      }
    }
  }

  Future<void> loadMore() async {
    try {
      await _pager.loadMore();
    } catch (_) {
      // Keep the current grid; the pager already reset its loading flag.
    }
  }

  /// Debounced free-text search.
  void setSearchText(String text) => _pager.setSearchText(text);

  Future<void> toggleTag(String tagId) async {
    final tagIds = Set<String>.of(_pager.tagIds);
    if (!tagIds.remove(tagId)) tagIds.add(tagId);
    await _applyQuery(tagIds: tagIds);
  }

  Future<void> clearFilters() async {
    clearSelection();
    await _applyQuery(searchText: '', tagIds: const {});
  }

  /// Applies a new filter. The previous grid stays visible while the new
  /// results load, avoiding a loading flash on every keystroke.
  Future<void> _applyQuery({String? searchText, Set<String>? tagIds}) async {
    _pager.setQuery(searchText: searchText, tagIds: tagIds);
    try {
      await _pager.refresh();
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

    _publish();
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
