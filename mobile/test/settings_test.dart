import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';

import 'helpers.dart';

void main() {
  testWidgets('settings screen renders with Swiss sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = buildAppRouter();
    await pumpApp(tester, router: router);
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsWidgets);
    expect(find.text('SYSTEM'), findsOneWidget);
    expect(find.text('LIGHT'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
  });

  testWidgets('a stored dark preference is restored on startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final router = buildAppRouter();
    await pumpApp(tester, router: router);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
