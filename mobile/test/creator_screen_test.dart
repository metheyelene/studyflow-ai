import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/about/creator_screen.dart';

Widget _wrap() {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    home: const CreatorScreen(),
  );
}

void main() {
  testWidgets('renders the creator card with monogram, name, role, and quote', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('MV'), findsOneWidget);
    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
    expect(find.text('Creator & Developer of StudyFlow AI'), findsOneWidget);
    expect(find.textContaining('Built with the goal of making studying more'), findsOneWidget);
  });

  testWidgets('shows the tappable email and Contact Creator button', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('mithilviswask@gmail.com'), findsOneWidget);
    expect(find.text('Contact Creator'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);
  });

  testWidgets('renders the About StudyFlow feature list', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Source-grounded AI study assistance'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Progress tracking'), findsOneWidget);
  });

  testWidgets('shows the real version from package config', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'StudyFlow AI',
      packageName: 'ai.studyflow.studyflow_mobile',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Read from the app config, never hard-coded in the widget.
    expect(find.textContaining('StudyFlow AI · Version 1.0.0 · Build 1'), findsOneWidget);
  });

  testWidgets('respects reduced motion by skipping the entrance animation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mithil Viswas Kasi'), findsOneWidget);
  });
}
