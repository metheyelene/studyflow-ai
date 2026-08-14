import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Floating translucent bottom navigation (phone). Blurred shell — this
/// is one of the few places per-card blur is worth its cost.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassCard(
          tone: GlassTone.surfaceStrong,
          blurred: g.blurEnabled,
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? g.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: g.primary.withValues(alpha: 0.22))
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: g.primary.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  switchInCurve: AppMotion.pressOut,
                  switchOutCurve: AppMotion.pressIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected ? g.primary : g.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? g.primary : g.textMuted,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
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

/// Floating translucent navigation rail (tablet / desktop).
class GlassNavigationRail extends StatelessWidget {
  const GlassNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.extended = false,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.surfaceStrong,
      blurred: g.blurEnabled,
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onDestinationSelected(i),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 16 : 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: i == currentIndex
                          ? g.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == currentIndex
                              ? items[i].selectedIcon
                              : items[i].icon,
                          size: 22,
                          color: i == currentIndex ? g.primary : g.textMuted,
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              color: i == currentIndex
                                  ? g.primary
                                  : g.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmented control mirroring the web Tabs.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.surfaceSubtle,
      radius: 14,
      padding: const EdgeInsets.all(4),
      // Scale down (never overflow) when the tab labels exceed the
      // available width — matters on narrow screens and wide fonts.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tabs.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: i == currentIndex
                        ? g.surfaceStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: i == currentIndex
                        ? Border.all(color: g.border)
                        : null,
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color: i == currentIndex ? g.textPrimary : g.textMuted,
                      fontSize: 13,
                      fontWeight: i == currentIndex
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
