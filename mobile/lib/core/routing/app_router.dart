import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/about/creator_screen.dart';
import '../../features/authentication/auth_controller.dart';
import '../../features/authentication/auth_models.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/signup_screen.dart';
import '../../features/authentication/splash_screen.dart';
import '../../features/audio/podcast_library_screen.dart';
import '../../features/audio/podcast_player_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/flashcards/flashcard_session_screen.dart';
import '../../features/flashcards/flashcards_screen.dart';
import '../../features/notebooks/notebooks_screen.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/onboarding/onboarding_models.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/premium/premium_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quizzes/quiz_session_screen.dart';
import '../../features/quizzes/quizzes_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/study/study_plan_screen.dart';
import '../../features/study/study_screen.dart';
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
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const notebooks = '/notebooks';
  static const notebookDetail = '/notebooks/:id';
  static const flashcards = '/flashcards';
  static const flashcardDeck = '/flashcards/:deckId';
  static const quizzes = '/quizzes';
  static const quizDetail = '/quizzes/:quizId';
  static const audio = '/audio';
  static const audioEpisode = '/audio/:episodeId';
  static const study = '/study';
  static const studyPlans = '/study/plans';
  static const studyPlanDetail = '/study/plans/:examId';
  static const progress = '/progress';
  static const profile = '/profile';
  static const premium = '/premium';
  static const settings = '/settings';
  static const aboutCreator = '/about/creator';
}

/// Pops the current pushed route when there is one; otherwise falls back to
/// the app home shell. Back buttons must use this instead of a bare
/// `context.pop()`, which throws when the page was reached via a deep link
/// (no history to pop) — e.g. a web URL landing directly on `/about/creator`.
extension AppBack on BuildContext {
  void popOrHome() {
    if (canPop()) {
      pop();
    } else {
      go(AppRoutes.home);
    }
  }
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
/// Auth + onboarding gating: the router listens to [authEvents] and
/// [onboardingEvents] and redirects — splash while the session restores,
/// `/login` when logged out, `/onboarding` while a fresh account hasn't
/// completed setup, and back into the app shell once it has.
GoRouter buildAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([authEvents, onboardingEvents]),
    redirect: (context, state) {
      final auth = authEvents.state;
      final loc = state.matchedLocation;
      final onAuthPage = loc == AppRoutes.login || loc == AppRoutes.signup;

      return switch (auth) {
        AuthInitializing() => loc == AppRoutes.splash ? null : AppRoutes.splash,
        // Splash is transient — never a resting place once auth resolves.
        AuthUnauthenticated() => onAuthPage ? null : AppRoutes.login,
        AuthAuthenticated() => _authenticatedRedirect(loc, onAuthPage),
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notebooks,
                builder: (context, state) => const NotebooksScreen(),
              ),
              GoRoute(
                path: AppRoutes.notebookDetail,
                builder: (context, state) =>
                    NotebooksScreen(selectedId: state.pathParameters['id']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.study,
                builder: (context, state) => const StudyScreen(),
              ),
              GoRoute(
                path: AppRoutes.studyPlanDetail,
                builder: (context, state) => StudyPlanScreen(
                  examId: state.pathParameters['examId'] ?? '',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.audio,
                builder: (context, state) => const PodcastLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.premium,
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aboutCreator,
        builder: (context, state) => const CreatorScreen(),
      ),
      GoRoute(
        path: AppRoutes.flashcards,
        builder: (context, state) => const FlashcardsScreen(),
      ),
      GoRoute(
        path: AppRoutes.flashcardDeck,
        builder: (context, state) => FlashcardSessionScreen(
          deckId: state.pathParameters['deckId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.quizzes,
        builder: (context, state) => const QuizzesScreen(),
      ),
      GoRoute(
        path: AppRoutes.quizDetail,
        builder: (context, state) =>
            QuizSessionScreen(quizId: state.pathParameters['quizId'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.audioEpisode,
        // Expansion-style push: the mini-player artwork flies to the
        // player's artwork (shared hero), while the page itself eases in
        // with a gentle rise — a morph, not a plain slide.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: AppMotion.medium,
          reverseTransitionDuration: AppMotion.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: PodcastPlayerScreen(
            episodeId: state.pathParameters['episodeId'] ?? '',
          ),
        ),
      ),
    ],
  );
}

/// Where a signed-in user may rest, depending on their onboarding state.
String? _authenticatedRedirect(String loc, bool onAuthPage) {
  final ob = onboardingEvents.status;

  // Auth pages and the splash are never resting places once signed in.
  if (onAuthPage || loc == AppRoutes.splash) {
    return ob == OnboardingStatus.needed
        ? AppRoutes.onboarding
        : AppRoutes.home;
  }
  // The onboarding screen is the only place a `needed` user may rest.
  if (loc == AppRoutes.onboarding) {
    return ob == OnboardingStatus.done ? AppRoutes.home : null;
  }
  return ob == OnboardingStatus.needed ? AppRoutes.onboarding : null;
}

/// The app's router instance.
final GoRouter appRouter = buildAppRouter();
