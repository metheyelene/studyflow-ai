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

      test('dark glass is obsidian-neutral; light keeps the teal cast', () {
        if (brightness == Brightness.light) {
          // Light glass is lit by the brand glow: the edge and top lip
          // carry a teal-cyan cast (green dominates red) instead of
          // neutral white/gray, which reads flat on near-white fills.
          expect(g.highlight.g, greaterThan(g.highlight.r));
          expect(g.border.g, greaterThan(g.border.r));
          expect(g.highlight.a, lessThan(0.65));
          expect(g.border.a, lessThan(0.3));
        } else {
          // Obsidian direction: the black canvas dominates and the accent
          // is precious. Surfaces are near-black (low luminance, neutral —
          // red ≈ green ≈ blue, no brand tint), and the glass edge/top lip
          // is a subtle neutral catch-light (low alpha), never a color wash.
          for (final c in [
            g.background,
            g.surface,
            g.surfaceStrong,
            g.floating,
          ]) {
            expect(c.r, closeTo(c.g, 0.02));
            expect(c.g, closeTo(c.b, 0.02));
          }
          expect(g.background.computeLuminance(), lessThan(0.01));
          expect(g.highlight.a, lessThan(0.15));
          expect(g.border.a, lessThan(0.15));
          expect(g.highlight.r, closeTo(g.highlight.g, 0.02));
          expect(g.border.r, closeTo(g.border.g, 0.02));
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

  // The visual identity, locked as a side-by-side snapshot: the OBSIDIAN
  // dark ramp (near-black neutral surfaces, neutral catch-light glass)
  // beside the TEAL-LIT light ramp (paper-family surfaces, teal-cast
  // glass lighting). Future theme edits that drift either ramp — a
  // surface gaining a tint, the glass lighting losing its cast, an accent
  // shifting hue — fail loudly here instead of silently changing how the
  // whole app looks. When an edit is intentional, update the snapshot in
  // the same commit.
  void expectGlassRamp(GlassTheme g, Map<String, Color> expected) {
    final actual = <String, Color>{
      'background': g.background,
      'surface': g.surface,
      'surfaceStrong': g.surfaceStrong,
      'surfaceSubtle': g.surfaceSubtle,
      'floating': g.floating,
      'border': g.border,
      'highlight': g.highlight,
      'primary': g.primary,
      'primarySoft': g.primarySoft,
      'secondary': g.secondary,
      'ai': g.ai,
      'audio': g.audio,
      'success': g.success,
      'warning': g.warning,
      'danger': g.danger,
    };
    for (final entry in expected.entries) {
      expect(actual[entry.key], entry.value, reason: 'glass.${entry.key}');
    }
  }

  void expectSchemeRamp(ColorScheme cs, Map<String, Color> expected) {
    final actual = <String, Color>{
      'surface': cs.surface,
      'surfaceContainerLowest': cs.surfaceContainerLowest,
      'surfaceContainerLow': cs.surfaceContainerLow,
      'surfaceContainer': cs.surfaceContainer,
      'surfaceContainerHigh': cs.surfaceContainerHigh,
      'surfaceContainerHighest': cs.surfaceContainerHighest,
    };
    for (final entry in expected.entries) {
      expect(actual[entry.key], entry.value, reason: 'scheme.${entry.key}');
    }
  }

  test('side-by-side token snapshot locks both ramps', () {
    // OBSIDIAN dark: near-black neutral surfaces, neutral white catch-light.
    expectGlassRamp(GlassTheme.dark, {
      'background': const Color(0xFF090B0C),
      'surface': const Color(0xC2101214),
      'surfaceStrong': const Color(0xE8141618),
      'surfaceSubtle': const Color(0x7F16181A),
      'floating': const Color(0xE617191B),
      'border': const Color(0x12FFFFFF),
      'highlight': const Color(0x0FFFFFFF),
      'primary': const Color(0xFF2DD4BF),
      'primarySoft': const Color(0x1A2DD4BF),
      'secondary': const Color(0xFF38BDF8),
      'ai': const Color(0xFF22D3EE),
      'audio': const Color(0xFFFB7185),
      'success': const Color(0xFF34D399),
      'warning': const Color(0xFFFBBF24),
      'danger': const Color(0xFFF87171),
    });
    // TEAL-LIT light: paper-family surfaces, teal-cast glass lighting.
    expectGlassRamp(GlassTheme.light, {
      'background': const Color(0xFFF4F6F6),
      'surface': const Color(0xD9FFFFFF),
      'surfaceStrong': const Color(0xECFFFFFF),
      'surfaceSubtle': const Color(0xB3FFFFFF),
      'floating': const Color(0xE9FFFFFF),
      'border': const Color(0x1F0F766E),
      'highlight': const Color(0x73CCFBF1),
      'primary': const Color(0xFF0F766E),
      'primarySoft': const Color(0x140F766E),
      'secondary': const Color(0xFF0369A1),
      'ai': const Color(0xFF0891B2),
      'audio': const Color(0xFFD9563B),
      'success': const Color(0xFF047857),
      'warning': const Color(0xFFB45309),
      'danger': const Color(0xFFB91C1C),
    });
    // M3 system ramps: dark steps the obsidian family, light the paper
    // family — the brand accent never tints whole surfaces in either mode.
    expectSchemeRamp(buildAppTheme(Brightness.dark).colorScheme, {
      'surface': const Color(0xFF111314),
      'surfaceContainerLowest': const Color(0xFF080A0B),
      'surfaceContainerLow': const Color(0xFF0D0F10),
      'surfaceContainer': const Color(0xFF111314),
      'surfaceContainerHigh': const Color(0xFF16181A),
      'surfaceContainerHighest': const Color(0xFF1C1E20),
    });
    expectSchemeRamp(buildAppTheme(Brightness.light).colorScheme, {
      'surface': const Color(0xFFF9FBFB),
      'surfaceContainerLowest': const Color(0xFFFFFFFF),
      'surfaceContainerLow': const Color(0xFFF4F7F7),
      'surfaceContainer': const Color(0xFFEDF1F1),
      'surfaceContainerHigh': const Color(0xFFE6EAEA),
      'surfaceContainerHighest': const Color(0xFFDFE4E4),
    });
  });
}
