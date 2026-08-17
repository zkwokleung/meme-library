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

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Pages: 0 Library, 1 Stickers, 2 Tags, 3 Settings.
  // Destinations add "Add" at index 2, which is an action, not a page.
  static const _addDestination = 2;

  var _pageIndex = 0;

  // Built on first visit: an eager IndexedStack would run SettingsScreen's
  // platform calls at startup.
  final _built = {0};

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
      // Back on another tab returns to the library first; the library's own
      // PopScope still guards selection mode.
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pageIndex != 0) {
          setState(() => _pageIndex = 0);
        }
      },
      child: Scaffold(
        // A nested messenger keeps the tab Scaffolds off the root messenger,
        // so snackbars fired inside a tab render once, not per Scaffold.
        body: ScaffoldMessenger(
          child: IndexedStack(
            index: _pageIndex,
            children: [
              const LibraryScreen(),
              page(1, () => const StickersScreen()),
              page(2, () => TagsScreen(onTagSelected: _showTag)),
              page(3, () => const SettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _destinationFor(_pageIndex),
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.collections_bookmark_outlined),
              selectedIcon: Icon(Icons.collections_bookmark),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_emotions_outlined),
              selectedIcon: Icon(Icons.emoji_emotions),
              label: 'Stickers',
            ),
            NavigationDestination(
              icon: _AddDestinationIcon(),
              label: 'Add',
              tooltip: 'Add meme',
            ),
            NavigationDestination(
              icon: Icon(Icons.sell_outlined),
              selectedIcon: Icon(Icons.sell),
              label: 'Tags',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled circle that makes the Add action stand out from the plain
/// destination icons around it.
class _AddDestinationIcon extends StatelessWidget {
  const _AddDestinationIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      child: Icon(Icons.add_rounded, color: scheme.onPrimary),
    );
  }
}
