import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/shared/widgets/ai/studyflow_ai_orb.dart';

Widget _wrap({bool active = false}) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    home: Scaffold(
      body: Center(child: StudyFlowAiOrb(active: active)),
    ),
  );
}

/// The current scale of the pulsing core, read from its transform.
double _coreScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(find.byKey(kStudyFlowAiOrbCore));
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  testWidgets('idle orb renders a settled sphere without the halo', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.byKey(kStudyFlowAiOrb), findsOneWidget);
    expect(find.byKey(kStudyFlowAiOrbCore), findsOneWidget);
    expect(find.byKey(kStudyFlowAiOrbHalo), findsNothing);
  });

  testWidgets('active orb shows the expanding halo ring', (tester) async {
    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();

    expect(find.byKey(kStudyFlowAiOrbHalo), findsOneWidget);
  });

  testWidgets('active orb pulses: the core scale changes over time', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();
    final start = _coreScale(tester);

    await tester.pump(const Duration(milliseconds: 300));
    final later = _coreScale(tester);

    expect(later, isNot(closeTo(start, 0.001)));
  });

  testWidgets('reduced motion freezes the orb in its settled resting state', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();

    // No halo, and the core sits still at rest (scale 1.0) — no pulse.
    expect(find.byKey(kStudyFlowAiOrbHalo), findsNothing);
    final start = _coreScale(tester);
    expect(start, closeTo(1.0, 0.001));

    await tester.pump(const Duration(milliseconds: 600));
    expect(_coreScale(tester), closeTo(start, 0.001));
  });

  testWidgets('semantics describe the orb state but content stays decorative', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();

    expect(
      find.bySemanticsLabel('StudyFlow AI is thinking'),
      findsOneWidget,
    );
  });
}
