import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';

import 'helpers.dart';

void main() {
  testWidgets('Appearance picker switches to dark and persists the choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = buildAppRouter();
    await pumpApp(tester, router: router);
    router.go('/settings');
    await tester.pumpAndSettle();

    // Defaults to following the system.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Expand the picker.
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);

    // Switch to dark — the whole app flips brightness immediately.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Settings'));
    expect(Theme.of(context).brightness, Brightness.dark);

    // And the preference is stored so a restart keeps it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'dark');
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

  testWidgets('switching back to light restores light mode', (tester) async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final router = buildAppRouter();
    await pumpApp(tester, router: router);
    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Settings'));
    expect(Theme.of(context).brightness, Brightness.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'light');
  });
}
