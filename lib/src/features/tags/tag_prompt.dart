import 'package:flutter/material.dart';

import '../../domain/tag.dart';

/// Free-text tag prompt with up to 8 existing-tag suggestions. Tags in
/// [exclude] are omitted from the suggestions. Returns the entered or
/// chosen name, or null when cancelled.
Future<String?> promptForTag(
  BuildContext context, {
  required List<Tag> allTags,
  List<Tag> exclude = const [],
}) {
  final excludedIds = {for (final tag in exclude) tag.id};
  final suggestions = allTags
      .where((tag) => !excludedIds.contains(tag.id))
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
