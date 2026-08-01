import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/import_controller.dart';
import '../features/library/library_screen.dart';

class MemeLibraryApp extends ConsumerStatefulWidget {
  const MemeLibraryApp({super.key, this.bindIncomingShares = true});

  /// Disabled in widget tests that don't exercise platform channels.
  final bool bindIncomingShares;

  @override
  ConsumerState<MemeLibraryApp> createState() => _MemeLibraryAppState();
}

class _MemeLibraryAppState extends ConsumerState<MemeLibraryApp> {
  @override
  void initState() {
    super.initState();
    if (widget.bindIncomingShares) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(importControllerProvider).bindIncomingShares();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6246EA);

    ThemeData theme(Brightness brightness) {
      final scheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
      return ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: brightness == Brightness.light
            ? const Color(0xFFF8F7FC)
            : null,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
        chipTheme: const ChipThemeData(shape: StadiumBorder()),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return MaterialApp(
      title: 'Meme Library',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const LibraryScreen(),
    );
  }
}
