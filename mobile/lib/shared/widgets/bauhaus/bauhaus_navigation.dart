// ─────────────────────────────────────────────────────────────────────
// BAUHAUS NAVIGATION — StudyFlow AI
//
// Architectural navigation: thick borders, white/off-white background,
// geometric selected state with colored block.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';

class BauhausNavItem {
  const BauhausNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.color = BauhausColors.black,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Color color;
}

/// Bottom navigation bar — Bauhaus style.
class BauhausBottomNav extends StatelessWidget {
  const BauhausBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BauhausNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BauhausColors.white,
        border: Border(
          top: BorderSide(
            color: BauhausColors.black,
            width: BauhausShapes.borderMedium,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(
                  child: _NavItem(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
                if (i != items.length - 1)
                  Container(
                    width: 1,
                    color: BauhausColors.black.withValues(alpha: 0.15),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BauhausNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BauhausColors.white : BauhausColors.black;
    final bgColor = selected ? BauhausColors.black : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: BauhausMotion.fast,
        color: bgColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? (item.selectedIcon ?? item.icon) : item.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              item.label.toUpperCase(),
              style: BauhausTypography.label.copyWith(
                color: color,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation rail — Bauhaus style for tablet/desktop.
class BauhausNavRail extends StatelessWidget {
  const BauhausNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.extended = false,
  });

  final List<BauhausNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 200 : 72,
      decoration: const BoxDecoration(
        color: BauhausColors.white,
        border: Border(
          right: BorderSide(
            color: BauhausColors.black,
            width: BauhausShapes.borderMedium,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: BauhausSpacing.lg),
          for (var i = 0; i < items.length; i++) ...[
            _RailItem(
              item: items[i],
              selected: i == currentIndex,
              onTap: () => onTap(i),
              extended: extended,
            ),
            if (i != items.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: BauhausSpacing.md,
                ),
                color: BauhausColors.black.withValues(alpha: 0.15),
              ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.extended = false,
  });

  final BauhausNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BauhausColors.white : BauhausColors.black;
    final bgColor = selected ? BauhausColors.black : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: BauhausMotion.fast,
        margin: const EdgeInsets.symmetric(
          horizontal: BauhausSpacing.xs,
          vertical: BauhausSpacing.xxs,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: extended ? BauhausSpacing.md : BauhausSpacing.xs,
          vertical: BauhausSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: selected
              ? Border.all(color: BauhausColors.black, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: extended
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              selected ? (item.selectedIcon ?? item.icon) : item.icon,
              color: color,
              size: 20,
            ),
            if (extended) ...[
              const SizedBox(width: BauhausSpacing.sm),
              Text(
                item.label.toUpperCase(),
                style: BauhausTypography.label.copyWith(
                  color: color,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
