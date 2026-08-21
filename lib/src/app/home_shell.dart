import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tag.dart';
import '../features/import/import_controller.dart';
import '../features/import/import_sheet.dart';
import '../features/library/library_controller.dart';
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stickers/stickers_screen.dart';
import '../features/tags/tags_screen.dart';
import 'floating_dock.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Pages: 0 Library, 1 Stickers, 2 Tags, 3 Settings.
  // Destinations add "Add" at index 2, which is an action, not a page.
  static const _addDestination = 2;
  static const _stickersPage = 1;

  var _pageIndex = 0;

  // Built on first visit: an eager IndexedStack would run SettingsScreen's
  // platform calls at startup.
  final _built = {0};

  /// The Stickers tab hosts its own navigation (pack detail, meme picker)
  /// inside the shell, so the bottom bar stays visible throughout.
  final _stickersNavigatorKey = GlobalKey<NavigatorState>();

  int _destinationFor(int page) => page < _addDestination ? page : page + 1;

  void _onDestinationSelected(int destination) {
    if (destination == _addDestination) {
      showImportSheet(context, ref);
      return;
    }
    final page = destination < _addDestination ? destination : destination - 1;
    setState(() {
      _pageIndex = page;
      _built.add(page);
    });
  }

  void _showTag(Tag tag) {
    final state = ref.read(libraryControllerProvider).value;
    // Ensure-selected rather than toggle: tapping an already-filtered tag
    // must not silently clear the filter.
    if (state != null && !state.tagIds.contains(tag.id)) {
      ref.read(libraryControllerProvider.notifier).toggleTag(tag.id);
    }
    setState(() => _pageIndex = 0);
  }

  void _showFeedback(ImportFeedback feedback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(feedback.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(importFeedbackProvider, (_, next) {
      final feedback = next.value;
      if (feedback != null) _showFeedback(feedback);
    });

    Widget page(int index, Widget Function() builder) =>
        _built.contains(index) ? builder() : const SizedBox.shrink();

    return PopScope(
      // Back pops the stickers tab's own stack first, then returns to the
      // library; the library's own PopScope still guards selection mode.
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Handled here rather than with NavigatorPopHandler: that widget's
        // PopScope stays registered while its IndexedStack child is
        // offstage, so a route left open on the hidden stickers stack
        // would hijack back on other tabs.
        final stickersNavigator = _stickersNavigatorKey.currentState;
        if (_pageIndex == _stickersPage &&
            stickersNavigator != null &&
            stickersNavigator.canPop()) {
          stickersNavigator.maybePop();
          return;
        }
        setState(() => _pageIndex = 0);
      },
      child: Scaffold(
        // Tabs paint behind the floating dock so content scrolls under it.
        extendBody: true,
        // A nested messenger keeps the tab Scaffolds off the root messenger,
        // so snackbars fired inside a tab render once, not per Scaffold.
        body: ScaffoldMessenger(
          child: IndexedStack(
            index: _pageIndex,
            children: [
              const LibraryScreen(),
              page(
                _stickersPage,
                () => Navigator(
                  key: _stickersNavigatorKey,
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const StickersScreen(),
                  ),
                ),
              ),
              page(2, () => TagsScreen(onTagSelected: _showTag)),
              page(3, () => const SettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: FloatingDock(
          selectedIndex: _destinationFor(_pageIndex),
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}
