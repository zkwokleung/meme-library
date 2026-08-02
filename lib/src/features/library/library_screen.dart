import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meme.dart';
import '../../services/platform/clipboard_service.dart';
import '../../services/providers.dart';
import '../detail/meme_detail_screen.dart';
import '../import/import_controller.dart';
import '../settings/settings_screen.dart';
import '../tags/tag_manager_sheet.dart';
import 'library_controller.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFeedback(ImportFeedback feedback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(feedback.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _importFromClipboard() async {
    await ref.read(importControllerProvider).importFromClipboard();
  }

  Future<void> _importFromUrl() async {
    final url = await _promptForUrl();
    if (url == null || url.trim().isEmpty) return;
    await ref.read(importControllerProvider).importFromUrl(url);
  }

  Future<String?> _promptForUrl() {
    return showDialog<String>(
      context: context,
      builder: (context) => const _UrlPromptDialog(),
    );
  }

  void _openImportSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Paste image'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _importFromClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Save from link'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _importFromUrl();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'You can also share images to Meme Library from any app.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMeme(Meme meme) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemeDetailScreen(memeId: meme.id),
      ),
    );
  }

  void _deleteWithUndo(Meme meme) {
    deleteMemeWithUndo(
      ScaffoldMessenger.of(context),
      ref.read(libraryControllerProvider.notifier),
      meme,
    );
  }

  void _openQuickActions(Meme meme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await copyMemeToClipboard(context, ref, meme);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                shareMeme(ref, meme);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteWithUndo(meme);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    ref.listen(importFeedbackProvider, (_, next) {
      final feedback = next.value;
      if (feedback != null) _showFeedback(feedback);
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openImportSheet,
        tooltip: 'Add meme',
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncData(:final value) => _LibraryBody(
            state: value,
            searchController: _searchController,
            onOpen: _openMeme,
            onQuickActions: _openQuickActions,
          ),
          AsyncError() => const Center(child: Text('Something went wrong')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({
    required this.state,
    required this.searchController,
    required this.onOpen,
    required this.onQuickActions,
  });

  final LibraryState state;
  final TextEditingController searchController;
  final void Function(Meme) onOpen;
  final void Function(Meme) onQuickActions;

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
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Meme Library'),
            actions: [
              IconButton(
                tooltip: 'Tags',
                icon: const Icon(Icons.sell_outlined),
                onPressed: () => showTagManagerSheet(context),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Semantics(
                label: 'Search',
                child: SearchBar(
                  controller: searchController,
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
                  return _MemeTile(
                    meme: meme,
                    onTap: () => onOpen(meme),
                    onLongPress: () => onQuickActions(meme),
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

class _MemeTile extends ConsumerWidget {
  const _MemeTile({
    required this.meme,
    required this.onTap,
    required this.onLongPress,
  });

  final Meme meme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStoreProvider);
    final label = meme.title ?? 'Meme';

    return Semantics(
      label: label,
      button: true,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Hero(
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
                'Save memes from your clipboard, another app, or a link.',
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

/// Hides [meme], schedules its deletion, and offers Undo for the whole
/// deletion window. Shared by the grid and the detail screen.
void deleteMemeWithUndo(
  ScaffoldMessengerState messenger,
  LibraryController controller,
  Meme meme,
) {
  const undoWindow = Duration(seconds: 5);
  controller.deleteWithUndo(meme, undoWindow: undoWindow);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Meme deleted'),
        behavior: SnackBarBehavior.floating,
        duration: undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.undoDelete(meme.id),
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

Future<void> shareMeme(WidgetRef ref, Meme meme) {
  final media = ref.read(mediaStoreProvider);
  return ref
      .read(shareServiceProvider)
      .shareFile(
        media.resolve(meme.relativePath).path,
        mimeType: meme.mimeType,
      );
}

/// Owns its text controller so it is disposed with the dialog.
class _UrlPromptDialog extends StatefulWidget {
  const _UrlPromptDialog();

  @override
  State<_UrlPromptDialog> createState() => _UrlPromptDialogState();
}

class _UrlPromptDialogState extends State<_UrlPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save from link'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'https://…'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
