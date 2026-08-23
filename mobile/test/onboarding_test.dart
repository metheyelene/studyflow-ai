import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_models.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_repository.dart';

import 'helpers.dart';

Future<void> completeOnboardingFlow(WidgetTester tester) async {
  // Step 1/5 — course.
  await tester.enterText(find.byType(TextField).first, 'Medicine');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();

  // Step 2/5 — subjects.
  await tester.enterText(find.byType(TextField).first, 'Anatomy, Physiology');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();

  // Step 3/5 — exams (optional; skip).
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();

  // Step 4/5 — daily minutes (60 preselected; skip).
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();

  // Step 5/5 — goals.
  await tester.ensureVisible(find.text('FLASHCARDS'));
  await tester.tap(find.text('FLASHCARDS'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('FINISH SETUP'));
  await tester.tap(find.text('FINISH SETUP'));
  await tester.pumpAndSettle();
}

void main() {
  test('onboarding route matches the web destination', () {
    expect(AppRoutes.onboarding, '/onboarding');
  });

  testWidgets(
    'signed-in user who has not completed onboarding lands on onboarding',
    (tester) async {
      await pumpApp(tester, onboardingStatus: OnboardingStatus.needed);

      expect(find.text('SET UP YOUR STUDY FLOW'), findsOneWidget);
      expect(find.text('Step 1 of 5 — Your course'), findsOneWidget);
    },
  );

  testWidgets('user who completed onboarding boots straight to the dashboard', (
    tester,
  ) async {
    await pumpApp(tester, onboardingStatus: OnboardingStatus.done);

    expect(find.text('Ready to study?'), findsOneWidget);
    expect(find.text('SET UP YOUR STUDY FLOW'), findsNothing);
  });

  testWidgets('unauthenticated users never see onboarding', (tester) async {
    await pumpApp(
      tester,
      signedIn: false,
      onboardingStatus: OnboardingStatus.needed,
    );

    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('SET UP YOUR STUDY FLOW'), findsNothing);
  });

  testWidgets(
    'completing onboarding posts the answers and unlocks the dashboard',
    (tester) async {
      final onboardingFake = FakeOnboardingRepository();
      await pumpApp(
        tester,
        onboarding: onboardingFake,
        onboardingStatus: OnboardingStatus.needed,
      );

      await completeOnboardingFlow(tester);

      expect(onboardingFake.submitCalls, 1);
      final payload = onboardingFake.lastPayload!;
      expect(payload.course, 'Medicine');
      expect(payload.subjects, 'Anatomy, Physiology');
      expect(payload.exams, isEmpty);
      expect(payload.dailyMinutes, 60);
      expect(payload.goals, ['flashcards']);
      expect(find.text('Ready to study?'), findsOneWidget);
    },
  );

  testWidgets('failed onboarding submit shows a friendly error and stays put', (
    tester,
  ) async {
    final onboardingFake = _ThrowingOnboardingRepository();
    await pumpApp(
      tester,
      onboarding: onboardingFake,
      onboardingStatus: OnboardingStatus.needed,
    );

    await completeOnboardingFlow(tester);

    expect(
      find.text('Please fill in every field to continue.'),
      findsOneWidget,
    );
    expect(find.text('SET UP YOUR STUDY FLOW'), findsOneWidget);
  });
}

/// Repository whose submit always fails, to exercise the error path.
class _ThrowingOnboardingRepository implements OnboardingRepository {
  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> submit(OnboardingPayload payload) async {
    throw const OnboardingException('Please fill in every field to continue.');
  }
}
