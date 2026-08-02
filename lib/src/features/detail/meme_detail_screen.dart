import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meme.dart';
import '../../domain/tag.dart';
import '../library/library_controller.dart';
import '../library/library_screen.dart';

class MemeDetailScreen extends ConsumerStatefulWidget {
  const MemeDetailScreen({super.key, required this.memeId});

  final String memeId;

  @override
  ConsumerState<MemeDetailScreen> createState() => _MemeDetailScreenState();
}

class _MemeDetailScreenState extends ConsumerState<MemeDetailScreen> {
  Meme? _meme;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final meme = await ref
        .read(libraryRepositoryProvider)
        .memeById(widget.memeId);
    if (!mounted) return;
    setState(() {
      _meme = meme;
      _titleController.text = meme?.title ?? '';
      _notesController.text = meme?.notes ?? '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Runs a repository mutation, handling the meme disappearing under us
  /// (a pending delete committing, or a restore replacing the library).
  Future<void> _mutate(Future<Meme> Function() body) async {
    try {
      final updated = await body();
      if (mounted) setState(() => _meme = updated);
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('This meme was deleted')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveMetadata() async {
    final meme = _meme;
    if (meme == null) return;
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    if ((meme.title ?? '') == title && (meme.notes ?? '') == notes) return;

    await _mutate(
      () => ref
          .read(libraryRepositoryProvider)
          .updateMetadata(
            meme.id,
            title: () => title.isEmpty ? null : title,
            notes: () => notes.isEmpty ? null : notes,
          ),
    );
  }

  Future<void> _addTag() async {
    final meme = _meme;
    if (meme == null) return;
    final allTags = await ref.read(libraryRepositoryProvider).allTags();
    if (!mounted) return;
    final name = await _promptForTag(allTags, meme.tags);
    if (name == null || Tag.normalize(name).isEmpty) return;

    final repository = ref.read(libraryRepositoryProvider);
    await _mutate(() async {
      final tag = await repository.ensureTag(name);
      return repository.setTags(meme.id, [...meme.tags, tag]);
    });
  }

  Future<String?> _promptForTag(List<Tag> allTags, List<Tag> current) {
    final existingIds = {for (final tag in current) tag.id};
    final suggestions = allTags
        .where((tag) => !existingIds.contains(tag.id))
        .toList(growable: false);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var input = '';
        return AlertDialog(
          title: const Text('Add tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Tag name'),
                onChanged: (value) => input = value,
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in suggestions.take(8))
                      ActionChip(
                        label: Text(tag.name),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(tag.name),
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(input),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeTag(Tag tag) async {
    final meme = _meme;
    if (meme == null) return;
    await _mutate(
      () => ref
          .read(libraryRepositoryProvider)
          .setTags(
            meme.id,
            meme.tags.where((t) => t.id != tag.id).toList(growable: false),
          ),
    );
  }

  void _delete() {
    final meme = _meme;
    if (meme == null) return;
    // Captured before pop: this context is gone afterwards. The undo
    // snackbar appears over the library grid underneath.
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(libraryControllerProvider.notifier);
    Navigator.of(context).pop();
    deleteMemeWithUndo(messenger, controller, meme);
  }

  @override
  Widget build(BuildContext context) {
    final meme = _meme;
    final media = ref.watch(mediaStoreProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveMetadata();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(meme?.title ?? ''),
          actions: [
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded),
              onPressed: meme == null
                  ? null
                  : () => copyMemeToClipboard(context, ref, meme),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_rounded),
              onPressed: meme == null ? null : () => shareMeme(ref, meme),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: meme == null ? null : _delete,
            ),
          ],
        ),
        body: meme == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      maxScale: 6,
                      child: Center(
                        child: Hero(
                          tag: 'meme-${meme.id}',
                          child: Image.file(
                            media.resolve(meme.relativePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'Title',
                              border: InputBorder.none,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                            onSubmitted: (_) => _saveMetadata(),
                            onTapOutside: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _saveMetadata();
                            },
                          ),
                          TextField(
                            controller: _notesController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'Notes',
                              border: InputBorder.none,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                            onSubmitted: (_) => _saveMetadata(),
                            onTapOutside: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _saveMetadata();
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in meme.tags)
                                InputChip(
                                  label: Text(tag.name),
                                  onDeleted: () => _removeTag(tag),
                                  deleteButtonTooltipMessage: 'Remove tag',
                                ),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Tag'),
                                onPressed: _addTag,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
