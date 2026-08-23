import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/about/creator_screen.dart';

import 'helpers.dart';

Widget _wrap() {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    home: const CreatorScreen(),
  );
}

void main() {
  testWidgets('renders the creator identity with name and title', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('STUDYFLOW AI'), findsOneWidget);
    expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
    expect(
      find.textContaining('study tool built for students'),
      findsOneWidget,
    );
  });

  testWidgets('renders the footer', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('MADE WITH PURPOSE'), findsOneWidget);
  });

  testWidgets(
    'deep-linked Back falls back to the home shell instead of throwing',
    (tester) async {
      await pumpApp(
        tester,
        router: buildAppRouter(initialLocation: AppRoutes.aboutCreator),
      );

      expect(find.text('MITHIL VISWAS KASI'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ready to study'), findsOneWidget);
    },
  );
}
