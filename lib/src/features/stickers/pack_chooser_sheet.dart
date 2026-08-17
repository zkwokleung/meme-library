import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sticker_pack.dart';
import 'sticker_packs_controller.dart';
import 'stickers_screen.dart';

/// Picks an existing pack (full ones are disabled) or creates a new one;
/// resolves to the chosen pack id, or null when dismissed.
Future<String?> showPackChooser(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _PackChooserSheet(),
    );

class _PackChooserSheet extends ConsumerWidget {
  const _PackChooserSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs =
        ref.watch(stickerPacksControllerProvider).value ??
        const <StickerPackSummary>[];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New pack…'),
            onTap: () => _createPack(context, ref),
          ),
          for (final pack in packs)
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(pack.name),
              subtitle: Text(
                pack.stickerCount >= StickerPack.maxStickers
                    ? 'Full (${StickerPack.maxStickers} stickers)'
                    : pack.stickerCount == 1
                    ? '1 sticker'
                    : '${pack.stickerCount} stickers',
              ),
              enabled: pack.stickerCount < StickerPack.maxStickers,
              onTap: () => Navigator.of(context).pop(pack.id),
            ),
        ],
      ),
    );
  }

  Future<void> _createPack(BuildContext context, WidgetRef ref) async {
    final name = await promptForPackName(context, title: 'New sticker pack');
    if (name == null || !context.mounted) return;
    final pack = await ref.read(stickerPackRepositoryProvider).createPack(name);
    if (context.mounted) Navigator.of(context).pop(pack.id);
  }
}
