import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_button.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_card.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_pill.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_progress.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('GlassCard renders its child', (tester) async {
    await tester.pumpWidget(
      _wrap(const GlassCard(child: Text('card content'))),
    );
    expect(find.text('card content'), findsOneWidget);
  });

  testWidgets('GlassPill shows selected state', (tester) async {
    await tester.pumpWidget(
      _wrap(const GlassPill(label: 'Favorites', selected: true)),
    );
    final semantics = tester.getSemantics(find.byType(GlassPill));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('GlassPill fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(GlassPill(label: 'All', onTap: () => tapped = true)),
    );
    await tester.tap(find.text('All'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'GlassButton fires onPressed when enabled and renders when disabled',
    (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(GlassButton(label: 'Run', onPressed: () => pressed = true)),
      );
      await tester.tap(find.text('Run'));
      expect(pressed, isTrue);

      await tester.pumpWidget(
        _wrap(const GlassButton(label: 'Busy', onPressed: null)),
      );
      expect(find.text('Busy'), findsOneWidget);
    },
  );

  testWidgets('GlassRing renders its label', (tester) async {
    await tester.pumpWidget(_wrap(const GlassRing(value: 0.5, label: '10/20')));
    expect(find.text('10/20'), findsOneWidget);
  });
}
