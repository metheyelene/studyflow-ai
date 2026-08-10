import 'package:go_router/go_router.dart';

import '../../features/about/creator_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/placeholders.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/home_shell.dart';

/// Route table. Deep-link targets (password reset, subscription
/// management, email verification) will register here in later phases —
/// the router is already set up to receive them.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeShell(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          child: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/notebooks', builder: (context, state) => const NotebooksScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/study', builder: (context, state) => const StudyScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/about/creator', builder: (context, state) => const CreatorScreen()),
    // Auth + onboarding routes register here in Phase 4–5.
  ],
);
