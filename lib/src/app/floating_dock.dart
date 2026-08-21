import 'package:flutter/material.dart';

/// The app's floating bottom navigation: a rounded dock inset from the
/// screen edges, with the center Add action raised as a filled circle.
///
/// Keeps the NavigationBar destination contract it replaced: indices
/// 0 Library, 1 Stickers, 2 Add (an action, not a page), 3 Tags, 4 Settings.
class FloatingDock extends StatelessWidget {
  const FloatingDock({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MediaQuery.withClampedTextScaling(
        // The dock is a fixed-height bar; labels scale up to a point and
        // rely on tooltips/semantics beyond that.
        maxScaleFactor: 1.3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(34),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  _DockDestination(
                    label: 'Library',
                    icon: Icons.collections_bookmark_outlined,
                    selectedIcon: Icons.collections_bookmark,
                    selected: selectedIndex == 0,
                    onTap: () => onDestinationSelected(0),
                  ),
                  _DockDestination(
                    label: 'Stickers',
                    icon: Icons.emoji_emotions_outlined,
                    selectedIcon: Icons.emoji_emotions,
                    selected: selectedIndex == 1,
                    onTap: () => onDestinationSelected(1),
                  ),
                  _AddButton(onTap: () => onDestinationSelected(2)),
                  _DockDestination(
                    label: 'Tags',
                    icon: Icons.sell_outlined,
                    selectedIcon: Icons.sell,
                    selected: selectedIndex == 3,
                    onTap: () => onDestinationSelected(3),
                  ),
                  _DockDestination(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    selected: selectedIndex == 4,
                    onTap: () => onDestinationSelected(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          child: InkResponse(
            onTap: onTap,
            radius: 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Tooltip(
        message: 'Add meme',
        child: Semantics(
          button: true,
          child: InkResponse(
            onTap: onTap,
            radius: 34,
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
