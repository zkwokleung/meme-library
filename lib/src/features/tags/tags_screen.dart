import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/tag.dart';
import '../library/library_controller.dart';

/// Tag cloud: every tag sized by how many memes carry it. Tap filters the
/// library; long-press renames or deletes.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key, required this.onTagSelected});

  final void Function(Tag) onTagSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final maxCount = tags.fold(0, (max, entry) => math.max(max, entry.$2));

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tags.isEmpty
          ? const Center(child: Text('No tags yet'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (tag, count) in tags)
                    GestureDetector(
                      // A Tooltip here would claim the long-press gesture,
                      // so the count lives in semantics and the sheet.
                      onLongPress: () =>
                          _showTagActions(context, ref, tag, count),
                      child: Semantics(
                        hint: '$count ${count == 1 ? 'meme' : 'memes'}',
                        child: ActionChip(
                          label: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: tagFontSize(count, maxCount),
                            ),
                          ),
                          onPressed: () => onTagSelected(tag),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showTagActions(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    int count,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: Text(tag.name),
              subtitle: Text('$count ${count == 1 ? 'meme' : 'memes'}'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _rename(context, ref, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(context, ref, tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Tag tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameTagDialog(initialName: tag.name),
    );
    if (newName == null || Tag.normalize(newName).isEmpty) return;

    try {
      await ref.read(libraryRepositoryProvider).renameTag(tag.id, newName);
    } on StateError catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${tag.name}"?'),
        content: const Text('The tag is removed from every meme.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryRepositoryProvider).deleteTag(tag.id);
  }
}

/// Log scale: tag counts are heavy-tailed, so a linear scale would pin
/// everything but the top tag at the minimum size.
double tagFontSize(int count, int maxCount) {
  const minSize = 14.0;
  const maxSize = 28.0;
  if (maxCount <= 1) return minSize;
  final t = math.log(count + 1) / math.log(maxCount + 1);
  return minSize + (maxSize - minSize) * t;
}

/// Owns its text controller so it is disposed with the dialog.
class _RenameTagDialog extends StatefulWidget {
  const _RenameTagDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameTagDialog> createState() => _RenameTagDialogState();
}

class _RenameTagDialogState extends State<_RenameTagDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename tag'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
