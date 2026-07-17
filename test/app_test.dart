import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/main.dart';

void main() {
  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MemeLibraryApp()));

    expect(find.text('Meme Library'), findsOneWidget);
    expect(find.text('Your meme stash starts here'), findsOneWidget);
    expect(
      find.text('Save memes from your clipboard, another app, or a link.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
  });
}
