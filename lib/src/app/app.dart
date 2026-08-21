import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/import_controller.dart';
import 'home_shell.dart';
import 'theme.dart';

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
        if (!mounted) return;
        unawaited(ref.read(importControllerProvider).bindIncomingShares());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meme Library',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
