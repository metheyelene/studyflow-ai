import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: StudyFlowApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('app boots to the home dashboard', (tester) async {
    await pumpApp(tester);

    expect(find.text('Ready to study?'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget); // bottom nav
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
}
