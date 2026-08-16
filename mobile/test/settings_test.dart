import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/settings/ai_preferences.dart';

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

  group('AI preferences', () {
    testWidgets(
      'expanding loads defaults and a style change saves server-side',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final ai = FakeAiPreferencesRepository();
        final router = buildAppRouter();
        await pumpApp(tester, router: router, aiPreferences: ai);
        router.go('/settings');
        await tester.pumpAndSettle();

        // Collapsed by default — the backend is only contacted on expand.
        expect(find.text('AI preferences'), findsOneWidget);
        expect(find.text('Concise'), findsNothing);

        await tester.tap(find.text('AI preferences'));
        await tester.pumpAndSettle();

        expect(ai.loadCalls, 1);
        expect(find.text('Concise'), findsOneWidget);
        expect(find.text('Balanced'), findsOneWidget);
        expect(find.text('University'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);

        await tester.tap(find.text('Concise'));
        await tester.pumpAndSettle();

        expect(ai.saved, hasLength(1));
        expect(ai.saved.single.responseStyle, AiResponseStyle.concise);
        expect(ai.current.responseStyle, AiResponseStyle.concise);
      },
    );

    testWidgets('study level and language changes persist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ai = FakeAiPreferencesRepository();
      final router = buildAppRouter();
      await pumpApp(tester, router: router, aiPreferences: ai);
      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI preferences'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Professional'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spanish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spanish'));
      await tester.pumpAndSettle();

      expect(ai.saved, hasLength(2));
      expect(ai.saved[0].studyLevel, AiStudyLevel.professional);
      expect(ai.saved[1].language, 'Spanish');
    });

    testWidgets('a failed save reverts and shows a friendly toast', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final ai = FakeAiPreferencesRepository()..failSave = true;
      final router = buildAppRouter();
      await pumpApp(tester, router: router, aiPreferences: ai);
      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI preferences'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Concise'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't save your preferences. Please try again."),
        findsOneWidget,
      );
      // Reverted to the last saved (default) value.
      expect(ai.current.responseStyle, AiResponseStyle.balanced);

      // Let the toast's auto-dismiss timer fire so the test ends clean.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pumpAndSettle();
    });
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
