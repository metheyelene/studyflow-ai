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
    expect(find.text('PROFILE'), findsOneWidget); // bottom nav (Swiss uppercase)
  });

  testWidgets('quick actions render and Ask AI navigates to notebooks', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('QUICK'), findsOneWidget);
    expect(find.text('ASK AI'), findsOneWidget);
    expect(find.text('FLASHCARDS'), findsOneWidget);
    expect(find.text('QUIZ'), findsOneWidget);
    expect(find.text('PODCAST'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('NO UPCOMING EXAMS'), findsOneWidget);

    await tester.ensureVisible(find.text('ASK AI'));
    await tester.tap(find.text('ASK AI'));
    await tester.pumpAndSettle();

    // Real navigation: the notebooks tab opens with its honest empty state.
    expect(find.text('NO STUDY SPACES'), findsOneWidget);
  });

  testWidgets(
    'every quick action lands on the tab mirroring its web destination',
    (tester) async {
      await pumpApp(tester);

      // Mirrors the web dashboard QUICK_ACTIONS: Ask AI links to the
      // notebooks tab; Flashcards, Quiz, and Podcast have their own real
      // destinations.
      await tester.ensureVisible(find.text('ASK AI'));
      await tester.tap(find.text('ASK AI'));
      await tester.pumpAndSettle();
      expect(
        find.text('NO STUDY SPACES'),
        findsOneWidget,
        reason: 'Ask AI should open the notebooks tab',
      );
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('QUICK'), findsOneWidget);

      // Flashcards now has its own real screen (deck list).
      await tester.ensureVisible(find.text('FLASHCARDS'));
      await tester.tap(find.text('FLASHCARDS'));
      await tester.pumpAndSettle();
      expect(
        find.text('NO FLASHCARDS'),
        findsOneWidget,
        reason: 'Flashcards should open the flashcards screen',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Quiz now has its own real screen (quiz history).
      await tester.ensureVisible(find.text('QUIZ'));
      await tester.tap(find.text('QUIZ'));
      await tester.pumpAndSettle();
      expect(
        find.text('NO QUIZZES'),
        findsOneWidget,
        reason: 'Quiz should open the quizzes screen',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Podcast mirrors the audio tab (web: /audio).
      await tester.ensureVisible(find.text('PODCAST'));
      await tester.tap(find.text('PODCAST'));
      await tester.pumpAndSettle();
      expect(
        find.text('NO EPISODES'),
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

      expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);
      expect(find.text('CREATED BY'), findsOneWidget);
    },
  );

  testWidgets('runtime deep link to /about/creator shows the Creator screen', (
    tester,
  ) async {
    final router = buildAppRouter();
    await pumpApp(tester, router: router);

    router.go(AppRoutes.aboutCreator);
    await tester.pumpAndSettle();

    expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
  });

  testWidgets('profile tab links to About StudyFlow → Creator', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('ABOUT STUDYFLOW'), findsWidgets);

    await tester.ensureVisible(find.text('ABOUT STUDYFLOW').last);
    await tester.tap(find.text('ABOUT STUDYFLOW').last);
    await tester.pumpAndSettle();

    expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
  });

  testWidgets('settings path reaches the Creator screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CREATOR'));
    await tester.tap(find.text('CREATOR'));
    await tester.pumpAndSettle();

    expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
  });
}
