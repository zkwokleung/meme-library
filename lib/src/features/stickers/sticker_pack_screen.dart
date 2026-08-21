import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sticker_pack.dart';
import '../../services/platform/sticker_pack_installer.dart';
import '../../stickers/whatsapp_sticker_exporter.dart';
import '../../widgets/meme_thumb.dart';
import 'meme_picker_screen.dart';
import 'sticker_packs_controller.dart';

class StickerPackScreen extends ConsumerWidget {
  const StickerPackScreen({required this.packId, super.key});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(stickerPackDetailProvider(packId)).value;
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This pack no longer exists')),
      );
    }
    final canExport = pack.items.length >= StickerPack.minStickers;
    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
        actions: [
          IconButton(
            tooltip: 'Add to...',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _showAddToSheet(context, ref, canExport),
          ),
        ],
      ),
      // Lifted above the floating dock, whose height arrives as MediaQuery
      // padding via the root Scaffold's extendBody.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton(
          tooltip: 'Add memes',
          onPressed: pack.items.length >= StickerPack.maxStickers
              ? null
              : () => _addMemes(context, ref),
          child: const Icon(Icons.add_photo_alternate_outlined),
        ),
      ),
      body: pack.items.isEmpty
          ? Center(
              child: Text(
                'Add at least ${StickerPack.minStickers} memes to export '
                'this pack',
                textAlign: TextAlign.center,
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: pack.items.length,
              itemBuilder: (context, index) =>
                  _StickerTile(packId: packId, item: pack.items[index]),
            ),
    );
  }

  Future<void> _addMemes(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(stickerPackRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await MemePickerScreen.pick(context);
    if (picked == null || picked.isEmpty) return;

    final outcome = await repository.addMemes(packId, picked);
    final parts = [
      if (outcome.added > 0) '${outcome.added} added',
      if (outcome.skippedDuplicates > 0)
        '${outcome.skippedDuplicates} already in the pack',
      if (outcome.skippedOverCapacity > 0)
        '${outcome.skippedOverCapacity} over the '
            '${StickerPack.maxStickers}-sticker limit',
    ];
    if (parts.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(parts.join(', ')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Destination chooser; WhatsApp is the only target today, but the sheet
  /// leaves room for more.
  Future<void> _showAddToSheet(
    BuildContext context,
    WidgetRef ref,
    bool canExport,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      // Escape the nested stickers navigator, whose overlay would leave
      // the bottom bar tappable under the barrier.
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Add to...',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              enabled: canExport,
              onTap: () => Navigator.of(sheetContext).pop('whatsapp'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'whatsapp' && context.mounted) {
      await _exportToWhatsApp(context, ref);
    }
  }

  Future<void> _exportToWhatsApp(BuildContext context, WidgetRef ref) async {
    final exporter = ref.read(whatsAppStickerExporterProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
    StickerExportOutcome outcome;
    try {
      outcome = await exporter.export(packId);
    } finally {
      navigator.pop();
    }

    final skipped = outcome.failedMemeIds.length;
    final message = switch ((outcome.result, outcome.error)) {
      (InstallStickerPackResult.added, _) => 'Added to WhatsApp',
      (InstallStickerPackResult.started, _) => 'Sent to WhatsApp',
      (InstallStickerPackResult.cancelled, _) =>
        'WhatsApp did not add the pack',
      (InstallStickerPackResult.whatsappNotInstalled, _) =>
        'Install WhatsApp to add sticker packs',
      (_, StickerExportError.tooFewStickers) =>
        'A pack needs at least ${StickerPack.minStickers} exportable '
            'stickers',
      _ => 'Could not add the pack to WhatsApp',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            skipped == 0 ? message : '$message ($skipped memes skipped)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _StickerTile extends ConsumerWidget {
  const _StickerTile({required this.packId, required this.item});

  final String packId;
  final StickerPackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MemeThumb(
          meme: item.meme,
          borderRadius: 12,
          onTap: () => _showStickerSheet(context, ref),
        ),
        if (item.emojis.isNotEmpty)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              // The overlay must not steal taps from the tile beneath.
              child: IgnorePointer(child: Text(item.emojis.join())),
            ),
          ),
      ],
    );
  }

  Future<void> _showStickerSheet(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(stickerPackRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Escape the nested stickers navigator, whose overlay would leave
      // the bottom bar tappable under the barrier.
      useRootNavigator: true,
      builder: (_) => _StickerSheet(
        initialEmojis: item.emojis,
        onEmojis: (emojis) =>
            repository.setEmojis(packId, item.meme.id, emojis),
        onRemove: () => repository.removeMeme(packId, item.meme.id),
      ),
    );
  }
}

class _StickerSheet extends StatefulWidget {
  const _StickerSheet({
    required this.initialEmojis,
    required this.onEmojis,
    required this.onRemove,
  });

  final List<String> initialEmojis;
  final void Function(List<String> emojis) onEmojis;
  final VoidCallback onRemove;

  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet> {
  late final _controller = TextEditingController(
    text: widget.initialEmojis.join(' '),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final emojis = _controller.text
        .split(RegExp(r'[\s,]+'))
        .where((e) => e.isNotEmpty)
        .take(StickerPack.maxEmojisPerSticker)
        .toList();
    widget.onEmojis(emojis);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText:
                  'Emojis (up to ${StickerPack.maxEmojisPerSticker}, '
                  'space separated)',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save emojis')),
          TextButton.icon(
            onPressed: () {
              widget.onRemove();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove from pack'),
          ),
        ],
      ),
    );
  }
}
