import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: StudyFlowApp()));
    await tester.pumpAndSettle();
  }

  // Fresh router per test — never mutate the app-global [appRouter]
  // singleton, or router state leaks across tests.
  Future<void> pumpRouterApp(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAppTheme(Brightness.light),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('about/creator path matches the web route exactly', () {
    expect(AppRoutes.aboutCreator, '/about/creator');
  });

  testWidgets('app boots to the home dashboard', (tester) async {
    await pumpApp(tester);

    expect(find.text('Ready to study?'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget); // bottom nav
  });

  testWidgets('deep link to /about/creator opens the Creator screen on launch',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildAppRouter(initialLocation: AppRoutes.aboutCreator);
    await pumpRouterApp(tester, router);

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('MV'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
  });

  testWidgets('runtime deep link to /about/creator shows the Creator screen',
      (tester) async {
    final router = buildAppRouter();
    await pumpRouterApp(tester, router);

    router.go(AppRoutes.aboutCreator);
    await tester.pumpAndSettle();

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
  });

  testWidgets('profile tab links to About StudyFlow → Creator', (tester) async {
    final router = buildAppRouter();
    await pumpRouterApp(tester, router);

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
    final router = buildAppRouter();
    await pumpRouterApp(tester, router);

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
