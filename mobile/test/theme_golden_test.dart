import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';

import 'helpers.dart';

/// Golden-image baselines for the Home screen in both modes, rendered at a
/// fixed phone surface with the real router and fake repositories (see
/// [pumpApp]). These catch visual regressions the token snapshot can't —
/// layout drift, glass rendering, ambient composition, spacing, and shadows.
///
/// Regenerate when a change is intentional:
///   flutter test --update-goldens test/theme_golden_test.dart
///
/// Notes:
///  * Goldens are font-independent in a layout sense — flutter_test renders
///    text with the blocky FlutterTest font, so these lock composition and
///    color, not typography.
///  * Goldens are platform-sensitive (anti-aliasing differs per OS); the
///    baselines were generated on the machine that owns them.
void main() {
  const size = Size(390, 844);

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('Home golden — $mode', (tester) async {
      // ThemeMode.system → the app follows platform brightness.
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue,
      );

      await pumpApp(
        tester,
        size: size,
        tier: PerformanceTier.standard,
      );
      // Router redirects to /home; let the dashboard's finite progress
      // tween and the atmosphere settle to a stable frame.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$mode.png'),
      );
    });
  }
}
