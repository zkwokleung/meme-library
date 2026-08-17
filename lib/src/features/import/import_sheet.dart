import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_controller.dart';

/// Opens the add sheet: save from photos, clipboard, or a link.
///
/// [context] must outlive the sheet (it hosts the URL prompt dialog), so pass
/// a screen-level context, not the sheet's own.
Future<void> showImportSheet(BuildContext context, WidgetRef ref) {
  Future<void> importFromUrl() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => const _UrlPromptDialog(),
    );
    if (url == null || url.trim().isEmpty) return;
    await ref.read(importControllerProvider).importFromUrl(url);
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      // Three tiles plus the footer overflow a short sheet at large text
      // scales.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Save from photos'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(importControllerProvider).importFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Paste image'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(importControllerProvider).importFromClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Save from link'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                importFromUrl();
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
    ),
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
