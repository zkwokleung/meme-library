import 'package:flutter/material.dart';

const kBrandSeed = Color(0xFFE4572E);
const kPaper = Color(0xFFFAF7F1);
const kInk = Color(0xFF1D1A15);
const kMuted = Color(0xFF8D8577);
const kChipFill = Color(0xFFF0EADC);
const kDarkScaffold = Color(0xFF171412);
const kDisplayFontFamily = 'BricolageGrotesque';

/// The single theme builder, shared by the app and the screenshot tool.
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final seeded = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: brightness,
  );
  // fromSeed derives cool-tinted neutrals; pull them toward Sunroom's warm
  // paper/ink palette while keeping the seeded accent roles.
  final scheme = light
      ? seeded.copyWith(
          // Seeded tone 40 drifts brick-brown; the brand vermilion keeps
          // 5.2:1 on white.
          primary: const Color(0xFFC43E14),
          surface: Colors.white,
          onSurface: kInk,
          surfaceContainerHighest: kChipFill,
          onSurfaceVariant: const Color(0xFF5C554A),
          outline: kMuted,
          outlineVariant: const Color(0xFFE9E3D6),
        )
      : seeded.copyWith(
          surface: const Color(0xFF1E1A16),
          onSurface: const Color(0xFFECE6DC),
          surfaceContainerHighest: const Color(0xFF2B251E),
          onSurfaceVariant: const Color(0xFFB3AA9C),
          outline: kMuted,
          outlineVariant: const Color(0xFF3A332B),
        );

  final theme = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? kPaper : kDarkScaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: kDisplayFontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: scheme.onSurface,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surface),
      side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );

  TextStyle? display(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: kDisplayFontFamily, fontWeight: weight);

  final text = theme.textTheme;
  return theme.copyWith(
    textTheme: text.copyWith(
      displaySmall: display(text.displaySmall, FontWeight.w800),
      headlineMedium: display(text.headlineMedium, FontWeight.w800),
      headlineSmall: display(text.headlineSmall, FontWeight.w800),
      titleLarge: display(text.titleLarge, FontWeight.w600),
      titleMedium: display(text.titleMedium, FontWeight.w600),
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      backgroundColor: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      // Chip does not merge a partial labelStyle with its defaults, so the
      // family and color must be spelled out.
      labelStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
  );
}
