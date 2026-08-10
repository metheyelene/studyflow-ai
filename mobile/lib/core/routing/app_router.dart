import 'package:go_router/go_router.dart';

import '../../features/about/creator_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/placeholders.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/home_shell.dart';

/// Canonical route paths — the single source of truth for navigation and
/// deep links. `/about/creator` matches the public web route exactly, so a
/// web URL (`https://studyflow.ai/about/creator`) resolves to the same
/// screen in the app.
abstract final class AppRoutes {
  static const home = '/home';
  static const notebooks = '/notebooks';
  static const study = '/study';
  static const progress = '/progress';
  static const profile = '/profile';
  static const settings = '/settings';
  static const aboutCreator = '/about/creator';
}

/// Builds the app router. `initialLocation` exists so deep-link launches
/// (app opened on `/about/creator`) are testable.
///
/// Deep links: go_router (v16+) matches incoming URLs by path, so a web URL
/// like `https://studyflow.ai/about/creator` handed to the OS resolves to
/// the route registered at `/about/creator` regardless of scheme/host. The
/// platform registration that makes the OS deliver those URLs (iOS Universal
/// Links / Android App Links) lands in the release-prep phases.
GoRouter buildAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
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
            GoRoute(path: AppRoutes.home, builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.notebooks, builder: (context, state) => const NotebooksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.study, builder: (context, state) => const StudyScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.progress, builder: (context, state) => const ProgressScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: AppRoutes.aboutCreator, builder: (context, state) => const CreatorScreen()),
      // Auth + onboarding routes register here in Phase 4–5.
    ],
  );
}

/// The app's router instance.
final GoRouter appRouter = buildAppRouter();
