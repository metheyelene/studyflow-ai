import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/authentication/auth_controller.dart';
import 'package:studyflow_mobile/features/authentication/auth_repository.dart';
import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';

import 'helpers.dart';

Future<void> enterEmailPassword(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unauthenticated boot lands on the login screen', (tester) async {
    await pumpApp(tester, signedIn: false);

    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('successful login reaches the dashboard', (tester) async {
    final auth = await pumpApp(tester, signedIn: false);

    await enterEmailPassword(tester, 'student@example.com', 'password123');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(auth.lastSignInEmail, 'student@example.com');
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('failed login shows a friendly error and stays on login', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: false);

    await enterEmailPassword(tester, 'fail@example.com', 'wrong');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets('login links to signup; signing up reaches the dashboard', (
    tester,
  ) async {
    final auth = await pumpApp(tester, signedIn: false);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE YOUR ACCOUNT'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'New Student');
    await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(auth.signUpCalls, 1);
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('boot from splash: signed-out session restore lands on login', (
    tester,
  ) async {
    // Mirrors production boot: state starts initializing, the router shows
    // the splash, then restore() resolves to signed-out (regression for the
    // redirect that stranded users on /splash once auth resolved).
    authEvents.reset();
    final auth = FakeAuthRepository(current: null);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          notebooksRepositoryProvider.overrideWithValue(
            FakeNotebooksRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: buildAppRouter(),
          theme: buildAppTheme(Brightness.light),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // While restoring, the app sits on the splash.
    expect(find.text('STUDYFLOW'), findsOneWidget);

    // main.dart fires restore() from initState; mimic it.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    await container.read(authControllerProvider.notifier).restore();
    await tester.pumpAndSettle();

    // The splash must not linger — signed out means login.
    expect(find.text('STUDYFLOW'), findsNothing);
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets('signing out from the profile returns to login', (tester) async {
    final auth = await pumpApp(tester);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('TEST USER'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    await container.read(authControllerProvider.notifier).signOut();
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets(
    'a different account never sees the previous user\'s cached dashboard data',
    (tester) async {
      // Regression: user-scoped providers were cached across sign-out/sign-in,
      // so a second account on the same device saw the first account's exams.
      final dashboard = FakeDashboardRepository(
        currentExams: [
          const UpcomingExam(
            id: 'ex-a',
            title: 'User A Exam',
            date: '2026-09-15T00:00:00.000Z',
          ),
        ],
      );
      await pumpApp(tester, dashboard: dashboard);
      expect(find.text('USER A EXAM'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.text('WELCOME BACK'), findsOneWidget);

      // The next account's data differs; the dashboard must refetch.
      dashboard.currentExams = [
        const UpcomingExam(
          id: 'ex-b',
          title: 'User B Exam',
          date: '2026-09-16T00:00:00.000Z',
        ),
      ];
      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'b@example.com', password: 'password123');
      await tester.pumpAndSettle();

      expect(find.text('USER B EXAM'), findsOneWidget);
      expect(find.text('USER A EXAM'), findsNothing);
    },
  );
}
