import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sticker_pack.dart';
import 'sticker_pack_screen.dart';
import 'sticker_packs_controller.dart';

class StickersScreen extends ConsumerWidget {
  const StickersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(stickerPacksControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stickers')),
      // Lifted above the floating dock, whose height arrives as MediaQuery
      // padding via the root Scaffold's extendBody.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton(
          tooltip: 'New sticker pack',
          onPressed: () => _createPack(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
      body: switch (packs) {
        AsyncData(value: final summaries) when summaries.isEmpty =>
          const _EmptyState(),
        AsyncData(value: final summaries) => ListView.builder(
          itemCount: summaries.length,
          itemBuilder: (context, index) => _PackTile(summary: summaries[index]),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _createPack(BuildContext context, WidgetRef ref) async {
    final name = await promptForPackName(context, title: 'New sticker pack');
    if (name == null) return;
    await ref.read(stickerPacksControllerProvider.notifier).createPack(name);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            color: theme.colorScheme.primary,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text('No sticker packs yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Bundle memes into packs you can add to WhatsApp.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _PackAction { rename, delete }

class _PackTile extends ConsumerWidget {
  const _PackTile({required this.summary});

  final StickerPackSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStoreProvider);
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StickerPackScreen(packId: summary.id),
        ),
      ),
      leading: summary.previewThumbnailPaths.isEmpty
          ? const CircleAvatar(child: Icon(Icons.emoji_emotions_outlined))
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                media.resolve(summary.previewThumbnailPaths.first),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
      title: Text(summary.name),
      subtitle: Text(
        summary.stickerCount == 1
            ? '1 sticker'
            : '${summary.stickerCount} stickers',
      ),
      trailing: PopupMenuButton<_PackAction>(
        tooltip: 'Pack options',
        // Escape the nested stickers navigator, whose overlay would leave
        // the bottom bar tappable under the barrier.
        useRootNavigator: true,
        onSelected: (action) => _handle(context, ref, action),
        itemBuilder: (context) => const [
          PopupMenuItem(value: _PackAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _PackAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _PackAction action,
  ) async {
    final controller = ref.read(stickerPacksControllerProvider.notifier);
    switch (action) {
      case _PackAction.rename:
        final name = await promptForPackName(
          context,
          title: 'Rename pack',
          initial: summary.name,
        );
        if (name == null) return;
        await controller.renamePack(summary.id, name);
      case _PackAction.delete:
        await controller.deletePack(summary.id);
    }
  }
}

/// Asks for a pack name; returns null on cancel or blank input.
Future<String?> promptForPackName(
  BuildContext context, {
  required String title,
  String? initial,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _PackNameDialog(title: title, initial: initial),
  );
  final trimmed = name?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

class _PackNameDialog extends StatefulWidget {
  const _PackNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_PackNameDialog> createState() => _PackNameDialogState();
}

class _PackNameDialogState extends State<_PackNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Pack name'),
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
