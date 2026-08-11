import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/about/creator_screen.dart';
import '../../features/authentication/auth_controller.dart';
import '../../features/authentication/auth_models.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/signup_screen.dart';
import '../../features/authentication/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/notebooks/notebooks_screen.dart';
import '../../features/placeholders.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/home_shell.dart';

/// Canonical route paths — the single source of truth for navigation and
/// deep links. `/about/creator` matches the public web route exactly, so a
/// web URL (`https://studyflow.ai/about/creator`) handed to the app
/// resolves to the same screen (it is auth-gated on mobile, like the web
/// app shell).
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const notebooks = '/notebooks';
  static const notebookDetail = '/notebooks/:id';
  static const study = '/study';
  static const progress = '/progress';
  static const profile = '/profile';
  static const settings = '/settings';
  static const aboutCreator = '/about/creator';
}

/// Builds the app router. `initialLocation` exists so deep-link launches
/// are testable.
///
/// Deep links: go_router (v16+) matches incoming URLs by path, so a web URL
/// like `https://studyflow.ai/about/creator` resolves to the route
/// registered at `/about/creator` regardless of scheme/host. The platform
/// registration that makes the OS deliver those URLs (iOS Universal Links /
/// Android App Links) lands in the release-prep phases.
///
/// Auth gating: the router listens to [authEvents] and redirects — splash
/// while the session restores, `/login` when logged out, and back into the
/// app when logged in.
GoRouter buildAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authEvents,
    redirect: (context, state) {
      final auth = authEvents.state;
      final loc = state.matchedLocation;
      final onAuthPage = loc == AppRoutes.login || loc == AppRoutes.signup;

      return switch (auth) {
        AuthInitializing() => loc == AppRoutes.splash ? null : AppRoutes.splash,
        // Splash is transient — never a resting place once auth resolves.
        AuthUnauthenticated() => onAuthPage ? null : AppRoutes.login,
        AuthAuthenticated() => (onAuthPage || loc == AppRoutes.splash) ? AppRoutes.home : null,
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (context, state) => const SignupScreen()),
      // Capture builds: the driver sets the signed-in flag in localStorage
      // directly (see mobile/tool/capture-screenshots.js), which the seeded
      // auth repository reads on the next full page load. No special route
      // is needed — a redirect would race the session restore.
      if (AppConfig.captureMode)
        GoRoute(
          path: '/capture/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('capture ok'))),
        ),
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
            GoRoute(
              path: AppRoutes.notebookDetail,
              builder: (context, state) =>
                  NotebooksScreen(selectedId: state.pathParameters['id']),
            ),
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
      // Onboarding routes register in Phase 5.
    ],
  );
}

/// The app's router instance.
final GoRouter appRouter = buildAppRouter();
