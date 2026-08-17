import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/authentication/auth_controller.dart';
import 'package:studyflow_mobile/features/authentication/auth_repository.dart';
import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_controller.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_repository.dart';
import 'package:studyflow_mobile/main.dart';

import 'helpers.dart';

void main() {
  test('about/creator path matches the web route exactly', () {
    expect(AppRoutes.aboutCreator, '/about/creator');
  });

  testWidgets('app boots to the home dashboard after session restore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    authEvents.reset();
    onboardingEvents.reset();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
          notebooksRepositoryProvider.overrideWithValue(
            FakeNotebooksRepository(),
          ),
        ],
        child: const StudyFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready to study?'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget); // bottom nav
  });

  testWidgets('quick actions render and Ask AI navigates to notebooks', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('QUICK'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('No upcoming exams'), findsOneWidget);

    await tester.ensureVisible(find.text('Ask AI'));
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    // Real navigation: the notebooks tab opens with its honest empty state.
    expect(find.text('No notebooks yet'), findsOneWidget);
  });

  testWidgets(
    'every quick action lands on the tab mirroring its web destination',
    (tester) async {
      await pumpApp(tester);

      // Mirrors the web dashboard QUICK_ACTIONS: Ask AI links to the
      // notebooks tab; Flashcards, Quiz, and Podcast have their own real
      // destinations.
      await tester.ensureVisible(find.text('Ask AI'));
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();
      expect(
        find.text('No notebooks yet'),
        findsOneWidget,
        reason: 'Ask AI should open the notebooks tab',
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('QUICK'), findsOneWidget);

      // Flashcards now has its own real screen (deck list).
      await tester.ensureVisible(find.text('Flashcards'));
      await tester.tap(find.text('Flashcards'));
      await tester.pumpAndSettle();
      expect(
        find.text('No decks yet'),
        findsOneWidget,
        reason: 'Flashcards should open the flashcards screen',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Quiz now has its own real screen (quiz history).
      await tester.ensureVisible(find.text('Quiz'));
      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      expect(
        find.text('No quizzes yet'),
        findsOneWidget,
        reason: 'Quiz should open the quizzes screen',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Podcast mirrors the audio tab (web: /audio).
      await tester.ensureVisible(find.text('Podcast'));
      await tester.tap(find.text('Podcast'));
      await tester.pumpAndSettle();
      expect(
        find.text('No podcasts yet'),
        findsOneWidget,
        reason: 'Podcast should open the audio tab',
      );
    },
  );

  testWidgets(
    'deep link to /about/creator opens the Creator screen on launch',
    (tester) async {
      final router = buildAppRouter(initialLocation: AppRoutes.aboutCreator);
      await pumpApp(tester, router: router);

      expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
      expect(find.text('MV'), findsOneWidget);
      expect(find.text('Contact Creator'), findsOneWidget);
    },
  );

  testWidgets('runtime deep link to /about/creator shows the Creator screen', (
    tester,
  ) async {
    final router = buildAppRouter();
    await pumpApp(tester, router: router);

    router.go(AppRoutes.aboutCreator);
    await tester.pumpAndSettle();

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
  });

  testWidgets('profile tab links to About StudyFlow → Creator', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('About StudyFlow'), findsWidgets);

    await tester.tap(find.text('About StudyFlow').last);
    await tester.pumpAndSettle();

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('MV'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
  });

  testWidgets('settings path reaches the Creator screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('About StudyFlow'), findsOneWidget);
    await tester.tap(find.text('About StudyFlow'));
    await tester.pumpAndSettle();

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
  });
}
