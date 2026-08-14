import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';

/// WCAG relative luminance of an sRGB color (WCAG 2.x definition).
double _luminance(Color c) {
  double f(double v) {
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// Contrast ratio between two opaque colors (1–21).
double _contrast(Color fg, Color bg) {
  final l1 = _luminance(fg);
  final l2 = _luminance(bg);
  final hi = l1 >= l2 ? l1 : l2;
  final lo = l1 >= l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// Composite a translucent color over an opaque background — the glass
/// surfaces carry alpha, so the effective painted color is the blend.
Color _composite(Color fg, Color bg) => Color.fromARGB(
      255,
      (fg.r * 255 * fg.a + bg.r * 255 * (1 - fg.a)).round(),
      (fg.g * 255 * fg.a + bg.g * 255 * (1 - fg.a)).round(),
      (fg.b * 255 * fg.a + bg.b * 255 * (1 - fg.a)).round(),
    );

const _aa = 4.5; // WCAG AA for normal text.

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    final label = brightness == Brightness.light ? 'light' : 'dark';
    final g = brightness == Brightness.light ? GlassTheme.light : GlassTheme.dark;
    final scheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: brightness,
      ),
    ).colorScheme;

    // Every surface the app paints glass on, composited over the background.
    final surfaces = <String, Color>{
      'surface': _composite(g.surface, g.background),
      'surfaceStrong': _composite(g.surfaceStrong, g.background),
      'surfaceSubtle': _composite(g.surfaceSubtle, g.background),
      'floating': _composite(g.floating, g.background),
      'background': g.background,
    };

    group('$label theme contrast (WCAG AA ≥ 4.5:1)', () {
      for (final entry in surfaces.entries) {
        test('textPrimary readable on ${entry.key}', () {
          expect(_contrast(g.textPrimary, entry.value), greaterThanOrEqualTo(_aa));
        });
        test('textMuted readable on ${entry.key}', () {
          expect(_contrast(g.textMuted, entry.value), greaterThanOrEqualTo(_aa));
        });
      }

      test('white-on-primary buttons', () {
        expect(_contrast(g.textOnPrimary, g.primary), greaterThanOrEqualTo(_aa));
      });

      test('brand primary as link text on surfaces', () {
        for (final entry in surfaces.entries) {
          expect(
            _contrast(g.primary, entry.value),
            greaterThanOrEqualTo(_aa),
            reason: 'primary as link on ${entry.key}',
          );
        }
      });

      test('status colors as text on surfaces', () {
        for (final c in [g.danger, g.success, g.warning]) {
          for (final entry in surfaces.entries) {
            expect(
              _contrast(c, entry.value),
              greaterThanOrEqualTo(_aa),
              reason: '$c on ${entry.key}',
            );
          }
        }
      });

      test('brand primary is the teal seed (indigo era removed)', () {
        if (brightness == Brightness.light) {
          expect(g.primary, AppColors.teal);
        } else {
          expect(g.primary, AppColors.tealLight);
        }
      });

      test('M3 scheme pairs', () {
        expect(_contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(_aa));
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(_aa),
        );
        expect(_contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(_aa));
        expect(
          _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(_aa),
        );
        expect(
          _contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThanOrEqualTo(_aa),
        );
      });
    });
  }
}
