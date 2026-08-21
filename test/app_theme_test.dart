import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meme_library/src/app/theme.dart';

void main() {
  test('light theme uses the Sunroom palette', () {
    final theme = buildTheme(Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, kPaper);
    expect(theme.colorScheme.onSurface, kInk);
    // The accent derives from the vermilion seed: red-dominant, not blue.
    expect(
      theme.colorScheme.primary.r,
      greaterThan(theme.colorScheme.primary.b),
    );
    expect(theme.textTheme.titleLarge?.fontFamily, kDisplayFontFamily);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, kDisplayFontFamily);
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);
  });

  test('dark theme keeps warm dark surfaces', () {
    final theme = buildTheme(Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, kDarkScaffold);
    expect(theme.textTheme.headlineSmall?.fontFamily, kDisplayFontFamily);
  });
}
