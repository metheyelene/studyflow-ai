import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';

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

  testWidgets('Reduce visual effects forces the low tier and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = buildAppRouter();
    await pumpApp(tester, router: router);
    router.go('/settings');
    await tester.pumpAndSettle();

    // Default: off → auto-detection decides the tier.
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Reduce visual effects'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Settings')),
    );
    expect(container.read(performanceTierProvider), detectPerformanceTier());

    // Flipping the switch forces the low tier live — the whole theme
    // rebuilds, so the glass blur radius drops immediately.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(performanceTierProvider), PerformanceTier.low);
    final g = Theme.of(
      tester.element(find.text('Settings')),
    ).extension<GlassTheme>()!;
    expect(g.blurRadius, 10);

    // And the preference persists for the next launch.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reduce_visual_effects'), isTrue);
  });

  testWidgets('a stored reduce-effects preference is restored on startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reduce_visual_effects': true});
    await pumpApp(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(container.read(performanceTierProvider), PerformanceTier.low);
    final g = Theme.of(
      tester.element(find.byType(Scaffold).first),
    ).extension<GlassTheme>()!;
    expect(g.blurRadius, 10);
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
