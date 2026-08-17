import 'package:flutter/material.dart';

class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stickers')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              color: theme.colorScheme.primary,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'Stickers are coming soon',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
