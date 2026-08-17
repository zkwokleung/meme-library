import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meme.dart';
import '../../domain/tag.dart';
import '../../services/platform/clipboard_service.dart';
import '../../services/platform/share_service.dart';
import '../../services/providers.dart';
import '../detail/meme_detail_screen.dart';
import '../stickers/pack_chooser_sheet.dart';
import '../tags/tag_prompt.dart';
import 'library_controller.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _focusSearch() async {
    // Scroll before focusing so the keyboard inset doesn't fight the
    // animation.
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted) _searchFocusNode.requestFocus();
  }

  void _openMeme(Meme meme) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemeDetailScreen(memeId: meme.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final selectionMode = state.value?.selectionMode ?? false;

    return PopScope(
      canPop: !selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(libraryControllerProvider.notifier).clearSelection();
        }
      },
      child: Scaffold(
        floatingActionButton: selectionMode
            ? null
            : FloatingActionButton(
                onPressed: _focusSearch,
                tooltip: 'Search',
                child: const Icon(Icons.search_rounded),
              ),
        body: SafeArea(
          child: switch (state) {
            AsyncData(:final value) => _LibraryBody(
              state: value,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              scrollController: _scrollController,
              onOpen: _openMeme,
            ),
            AsyncError() => const Center(child: Text('Something went wrong')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({
    required this.state,
    required this.searchController,
    required this.searchFocusNode,
    required this.scrollController,
    required this.onOpen,
  });

  final LibraryState state;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ScrollController scrollController;
  final void Function(Meme) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final showEmptyLibrary =
        state.items.isEmpty && !state.hasFilter && !state.loadingMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600) {
          ref.read(libraryControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            leading: state.selectionMode
                ? IconButton(
                    tooltip: 'Cancel selection',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref
                        .read(libraryControllerProvider.notifier)
                        .clearSelection(),
                  )
                : null,
            title: state.selectionMode
                ? Text('${state.selectedIds.length} selected')
                : const Text('Meme Library'),
            actions: state.selectionMode
                ? [_BulkActionsMenu(selectedCount: state.selectedIds.length)]
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Semantics(
                label: 'Search',
                child: SearchBar(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  hintText: 'Search',
                  elevation: const WidgetStatePropertyAll(0),
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (state.searchText.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          ref
                              .read(libraryControllerProvider.notifier)
                              .setSearchText('');
                        },
                      ),
                  ],
                  onChanged: (text) => ref
                      .read(libraryControllerProvider.notifier)
                      .setSearchText(text),
                ),
              ),
            ),
          ),
          if (tags.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final (tag, count) = tags[index];
                    return FilterChip(
                      label: Text(tag.name),
                      tooltip: '$count memes',
                      selected: state.tagIds.contains(tag.id),
                      onSelected: (_) => ref
                          .read(libraryControllerProvider.notifier)
                          .toggleTag(tag.id),
                    );
                  },
                ),
              ),
            ),
          if (showEmptyLibrary)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyLibrary(),
            )
          else if (state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NoMatches(
                onClear: () {
                  searchController.clear();
                  ref.read(libraryControllerProvider.notifier).clearFilters();
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final meme = state.items[index];
                  final controller = ref.read(
                    libraryControllerProvider.notifier,
                  );
                  return _MemeTile(
                    meme: meme,
                    selectionMode: state.selectionMode,
                    selected: state.selectedIds.contains(meme.id),
                    onTap: state.selectionMode
                        ? () => controller.toggleSelected(meme.id)
                        : () => onOpen(meme),
                    onLongPress: () => controller.toggleSelected(meme.id),
                  );
                },
              ),
            ),
          if (state.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BulkAction { copy, share, addTag, addToStickerPack, delete }

/// The "more" menu shown in the title bar while selecting; every action
/// operates on the current selection.
class _BulkActionsMenu extends ConsumerWidget {
  const _BulkActionsMenu({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCopy = selectedCount == 1;
    return PopupMenuButton<_BulkAction>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _BulkAction.copy,
          enabled: canCopy,
          child: ListTile(
            enabled: canCopy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy'),
          ),
        ),
        const PopupMenuItem(
          value: _BulkAction.share,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_rounded),
            title: Text('Share'),
          ),
        ),
        const PopupMenuItem(
          value: _BulkAction.addTag,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sell_outlined),
            title: Text('Add tag'),
          ),
        ),
        const PopupMenuItem(
          value: _BulkAction.addToStickerPack,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.emoji_emotions_outlined),
            title: Text('Add to sticker pack'),
          ),
        ),
        const PopupMenuItem(
          value: _BulkAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _BulkAction action,
  ) async {
    // Re-read live state: a reload may have pruned the selection since
    // the menu was opened.
    final controller = ref.read(libraryControllerProvider.notifier);
    final state = ref.read(libraryControllerProvider).value;
    if (state == null || state.selectedIds.isEmpty) {
      _showSelectionGone(ScaffoldMessenger.of(context));
      return;
    }
    final selected = state.selectedItems;

    switch (action) {
      case _BulkAction.copy:
        if (selected.length != 1) return;
        controller.clearSelection();
        await copyMemeToClipboard(context, ref, selected.single);
      case _BulkAction.share:
        controller.clearSelection();
        await shareMemes(context, ref, selected);
      case _BulkAction.addTag:
        await _addTagToSelection(context, ref, controller, selected);
      case _BulkAction.addToStickerPack:
        await _addSelectionToStickerPack(context, ref, controller, selected);
      case _BulkAction.delete:
        deleteMemesWithUndo(
          ScaffoldMessenger.of(context),
          controller,
          selected,
        );
    }
  }

  void _showSelectionGone(ScaffoldMessengerState messenger) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('The selection is no longer available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _addTagToSelection(
    BuildContext context,
    WidgetRef ref,
    LibraryController controller,
    List<Meme> selected,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final allTags = await ref.read(libraryRepositoryProvider).allTags();
    if (!context.mounted) return;

    // Suggest only tags missing from at least one selected meme.
    var commonIds = {for (final tag in selected.first.tags) tag.id};
    for (final meme in selected.skip(1)) {
      commonIds = commonIds.intersection({for (final tag in meme.tags) tag.id});
    }
    final exclude = [
      for (final tag in selected.first.tags)
        if (commonIds.contains(tag.id)) tag,
    ];

    final name = await promptForTag(
      context,
      allTags: allTags,
      exclude: exclude,
    );
    if (name == null || Tag.normalize(name).isEmpty) return;
    // The menu (and its ref) dies with selection mode; a reload can have
    // pruned the selection to empty while the dialog was open.
    if (!context.mounted) return;

    final live = ref.read(libraryControllerProvider).value;
    if (live == null || live.selectedIds.isEmpty) {
      _showSelectionGone(messenger);
      return;
    }
    final count = await controller.addTagToSelected(name);
    final trimmed = name.trim();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Already tagged'
                : count == 1
                ? 'Added "$trimmed" to 1 meme'
                : 'Added "$trimmed" to $count memes',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _addSelectionToStickerPack(
    BuildContext context,
    WidgetRef ref,
    LibraryController controller,
    List<Meme> selected,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Static stickers only: exclude animated memes rather than silently
    // flattening them to their first frame.
    final staticIds = [
      for (final meme in selected)
        if (!meme.thumbnailPath.endsWith('.gif')) meme.id,
    ];
    final skippedAnimated = selected.length - staticIds.length;
    if (staticIds.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Animated memes cannot become stickers'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final packId = await showPackChooser(context);
    if (packId == null) return;

    final outcome = await ref
        .read(stickerPackRepositoryProvider)
        .addMemes(packId, staticIds);
    controller.clearSelection();

    final parts = [
      if (outcome.added > 0) '${outcome.added} added',
      if (skippedAnimated > 0) '$skippedAnimated animated skipped',
      if (outcome.skippedDuplicates > 0)
        '${outcome.skippedDuplicates} already in the pack',
      if (outcome.skippedOverCapacity > 0)
        '${outcome.skippedOverCapacity} over the pack limit',
    ];
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(parts.join(', ')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _MemeTile extends ConsumerWidget {
  const _MemeTile({
    required this.meme,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Meme meme;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStoreProvider);
    final label = meme.title ?? 'Meme';
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: label,
      button: true,
      selected: selectionMode ? selected : null,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'meme-${meme.id}',
                child: Image.file(
                  media.resolve(meme.thumbnailPath),
                  fit: BoxFit.cover,
                  // Downsamples static thumbnails; a harmless no-op for
                  // animated GIF thumbnails (the engine ignores the target
                  // size for multi-frame codecs), which MediaStore already
                  // bounds to <=400px and <=48 frames.
                  cacheWidth: 320,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
              if (selectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.24)
                        : Colors.transparent,
                    border: selected
                        ? Border.all(color: colorScheme.primary, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                color: theme.colorScheme.primary,
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                'Your meme stash starts here',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Save memes from your photos, clipboard, another app, '
                'or a link.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No matches', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

/// Hides [memes], schedules their deletion, and offers Undo for the whole
/// deletion window. Shared by the grid's bulk menu and the detail screen.
void deleteMemesWithUndo(
  ScaffoldMessengerState messenger,
  LibraryController controller,
  List<Meme> memes,
) {
  const undoWindow = Duration(seconds: 5);
  final ids = controller.deleteManyWithUndo(memes, undoWindow: undoWindow);
  if (ids.isEmpty) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          ids.length == 1 ? 'Meme deleted' : '${ids.length} memes deleted',
        ),
        behavior: SnackBarBehavior.floating,
        duration: undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.undoDeleteMany(ids),
        ),
      ),
    );
}

/// Copies the original image to the clipboard, falling back to the share
/// sheet when the platform cannot host image data.
Future<void> copyMemeToClipboard(
  BuildContext context,
  WidgetRef ref,
  Meme meme,
) async {
  // Read everything up front: `ref` must not be touched after an await
  // (the calling widget may be disposed by then).
  final messenger = ScaffoldMessenger.of(context);
  final media = ref.read(mediaStoreProvider);
  final clipboard = ref.read(clipboardServiceProvider);
  final share = ref.read(shareServiceProvider);
  try {
    final bytes = await media.resolve(meme.relativePath).readAsBytes();
    final name = meme.relativePath.split('/').last;
    final copied = await clipboard.writeImage(
      ClipboardImage(bytes: bytes, suggestedName: name),
    );
    if (copied) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Copied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } else {
      await share.shareFile(
        media.resolve(meme.relativePath).path,
        mimeType: meme.mimeType,
      );
    }
  } on FileSystemException {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('The image file is missing'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

Future<void> shareMeme(BuildContext context, WidgetRef ref, Meme meme) =>
    shareMemes(context, ref, [meme]);

/// Opens the share sheet for the original images of [memes], skipping and
/// reporting files that are missing on disk.
Future<void> shareMemes(
  BuildContext context,
  WidgetRef ref,
  List<Meme> memes,
) async {
  // Read everything up front: `ref` must not be touched after an await
  // (the calling widget may be disposed by then).
  final messenger = ScaffoldMessenger.of(context);
  final media = ref.read(mediaStoreProvider);
  final share = ref.read(shareServiceProvider);

  final files = <ShareableFile>[];
  var missing = false;
  for (final meme in memes) {
    final file = media.resolve(meme.relativePath);
    if (await file.exists()) {
      files.add(ShareableFile(file.path, mimeType: meme.mimeType));
    } else {
      missing = true;
    }
  }
  if (missing) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('The image file is missing'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
  if (files.isEmpty) return;
  try {
    await share.shareFiles(files);
  } on Exception {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Something went wrong'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
