import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/tag.dart';
import '../library/library_controller.dart';

/// Opens the tag manager: rename or delete any tag.
void showTagManagerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _TagManagerSheet(),
  );
}

class _TagManagerSheet extends ConsumerWidget {
  const _TagManagerSheet();

  Future<void> _rename(BuildContext context, WidgetRef ref, Tag tag) async {
    final controller = TextEditingController(text: tag.name);
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        if (tags.isEmpty) {
          return const Center(child: Text('No tags yet'));
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final (tag, count) = tags[index];
            return ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: Text(tag.name),
              subtitle: Text('$count ${count == 1 ? 'meme' : 'memes'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(context, ref, tag),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context, ref, tag),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
