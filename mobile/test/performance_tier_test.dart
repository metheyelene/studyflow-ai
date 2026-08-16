import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_background.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_button.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_card.dart';

import 'helpers.dart';

Widget _wrap(Widget child, PerformanceTier tier) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light, tier: tier),
    home: Scaffold(body: child),
  );
}

void main() {
  group('tierForCores', () {
    test('≤4 cores is low; unknown (0) and 5+ are standard', () {
      expect(tierForCores(0), PerformanceTier.standard);
      expect(tierForCores(1), PerformanceTier.low);
      expect(tierForCores(4), PerformanceTier.low);
      expect(tierForCores(5), PerformanceTier.standard);
      expect(tierForCores(8), PerformanceTier.standard);
      expect(tierForCores(16), PerformanceTier.standard);
    });
  });

  group('low tier rendering', () {
    testWidgets('disables the ambient background', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.low);
      await tester.pumpAndSettle();

      expect(find.byKey(kStudyFlowBackgroundBase), findsOneWidget);
      expect(find.byKey(kStudyFlowBackgroundBlobs), findsNothing);
    });

    testWidgets('standard tier keeps the ambient background', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.standard);
      await tester.pumpAndSettle();

      expect(find.byKey(kStudyFlowBackgroundBlobs), findsOneWidget);
      expect(find.byKey(kStudyFlowBackgroundBase), findsNothing);
    });

    testWidgets('reduces the glass blur radius in light theme', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.low);
      await tester.pumpAndSettle();

      final g = Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).extension<GlassTheme>()!;
      // 24 → 10 on the low tier; small-sigma blur stays so sheets and the
      // nav keep their glass lip without paying full blur cost.
      expect(g.blurRadius, 10);
      expect(g.blurEnabled, isTrue);
    });

    testWidgets('standard tier keeps the full blur radius', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.standard);
      await tester.pumpAndSettle();

      final g = Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).extension<GlassTheme>()!;
      expect(g.blurRadius, 24);
    });

    testWidgets('low tier sets the reducedEffects theme flag', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.low);
      await tester.pumpAndSettle();

      final g = Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).extension<GlassTheme>()!;
      expect(g.reducedEffects, isTrue);
    });

    testWidgets('standard tier keeps effects enabled', (tester) async {
      await pumpApp(tester, tier: PerformanceTier.standard);
      await tester.pumpAndSettle();

      final g = Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).extension<GlassTheme>()!;
      expect(g.reducedEffects, isFalse);
    });

    testWidgets('GlassCard drops the glossy shadow and sheen on low tier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GlassCard(glossy: true, child: Text('card')),
          PerformanceTier.low,
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GlassCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = container.decoration! as BoxDecoration;
      // Only the softened black pair — the glossy primary glow is gone.
      expect(deco.boxShadow, hasLength(2));
      // No specular sheen or bottom-reflection gradient overlays (the
      // remaining DecoratedBox is the Container's own painted surface).
      final gradientBoxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((d) {
            final deco = d.decoration;
            return deco is BoxDecoration && deco.gradient != null;
          });
      expect(gradientBoxes, isEmpty);
    });

    testWidgets('GlassCard keeps glossy shadow and sheen on standard tier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GlassCard(glossy: true, child: Text('card')),
          PerformanceTier.standard,
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GlassCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.boxShadow, hasLength(3));
      final gradientBoxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((d) {
            final deco = d.decoration;
            return deco is BoxDecoration && deco.gradient != null;
          });
      expect(gradientBoxes, hasLength(2));
    });

    testWidgets('GlassButton drops its drop shadow on low tier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GlassButton(
            label: 'Go',
            variant: GlassButtonVariant.elevated,
            onPressed: () {},
          ),
          PerformanceTier.low,
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(Ink),
        ),
      );
      final deco = ink.decoration! as BoxDecoration;
      expect(deco.boxShadow, isNull);
    });

    testWidgets('GlassButton keeps its drop shadow on standard tier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GlassButton(
            label: 'Go',
            variant: GlassButtonVariant.elevated,
            onPressed: () {},
          ),
          PerformanceTier.standard,
        ),
      );

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(Ink),
        ),
      );
      final deco = ink.decoration! as BoxDecoration;
      expect(deco.boxShadow, hasLength(1));
    });
  });
}
