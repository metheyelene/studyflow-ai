import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/shared/widgets/ai/studyflow_ai_orb.dart';

Widget _wrap({bool active = false}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(
      body: Center(child: StudyFlowAiOrb(active: active)),
    ),
  );
}

void main() {
  testWidgets('orb renders with the key', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.byKey(kStudyFlowAiOrb), findsOneWidget);
  });

  testWidgets('active orb pulses', (tester) async {
    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();

    expect(find.byKey(kStudyFlowAiOrb), findsOneWidget);
  });

  testWidgets('semantics describe the orb state', (tester) async {
    await tester.pumpWidget(_wrap(active: true));
    await tester.pump();

    expect(find.bySemanticsLabel('StudyFlow AI is thinking'), findsOneWidget);
  });

  testWidgets('idle orb semantics', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.bySemanticsLabel('StudyFlow AI'), findsOneWidget);
  });
}
