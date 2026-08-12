import 'package:flutter/material.dart';

import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_nav.dart';

const kHomeNavItems = [
  GlassNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  GlassNavItem(
    label: 'Notebooks',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
  ),
  GlassNavItem(
    label: 'Study',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  GlassNavItem(
    label: 'Progress',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
  ),
  GlassNavItem(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

/// Adaptive navigation shell: floating bottom bar on phones, floating
/// rail on tablet/desktop. The branch body is provided by the router
/// (StatefulShellRoute.indexedStack).
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (context.isPhone)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassNavigationBar(
                items: kHomeNavItems,
                currentIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
              ),
            )
          else
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GlassNavigationRail(
                  items: kHomeNavItems,
                  currentIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  extended: context.isDesktop,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
