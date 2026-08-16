import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_background.dart';

/// WCAG relative luminance of an sRGB color (WCAG 2.x definition).
double _luminance(Color c) {
  double f(double v) {
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
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
    final g = brightness == Brightness.light
        ? GlassTheme.light
        : GlassTheme.dark;
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
          expect(
            _contrast(g.textPrimary, entry.value),
            greaterThanOrEqualTo(_aa),
          );
        });
        test('textMuted readable on ${entry.key}', () {
          expect(
            _contrast(g.textMuted, entry.value),
            greaterThanOrEqualTo(_aa),
          );
        });
      }

      test('white-on-primary buttons', () {
        expect(
          _contrast(g.textOnPrimary, g.primary),
          greaterThanOrEqualTo(_aa),
        );
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

      test('brand primary is the neutral seed (color removed)', () {
        if (brightness == Brightness.light) {
          expect(g.primary, AppColors.teal);
        } else {
          expect(g.primary, AppColors.tealLight);
        }
      });

      test('glass is strictly neutral in both modes', () {
        // Monochrome identity: every surface, edge, and catch-light is a
        // pure neutral — red ≈ green ≈ blue in both modes, so nothing in
        // the material system carries a hue. Dark keeps the obsidian
        // low-luminance base; light stays paper-bright.
        for (final c in [
          g.background,
          g.surface,
          g.surfaceStrong,
          g.surfaceSubtle,
          g.floating,
          g.highlight,
          g.border,
        ]) {
          expect(c.r, closeTo(c.g, 0.02), reason: '$c r≈g');
          expect(c.g, closeTo(c.b, 0.02), reason: '$c g≈b');
        }
        expect(g.highlight.a, lessThan(0.65));
        expect(g.border.a, lessThan(0.3));
        if (brightness == Brightness.dark) {
          expect(g.background.computeLuminance(), lessThan(0.01));
        } else {
          expect(g.background.computeLuminance(), greaterThan(0.9));
        }
      });

      test('M3 scheme pairs', () {
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(_aa),
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(_aa),
        );
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(_aa),
        );
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

  // The visual identity, locked as a side-by-side snapshot: the MONOCHROME
  // dark ramp (near-black neutral surfaces, white accent, neutral
  // catch-light glass) beside the MONOCHROME light ramp (paper-family
  // surfaces, black accent, gray-edged glass). Future theme edits that
  // drift either ramp — a surface gaining a tint, an accent shifting hue,
  // the white primary dimming — fail loudly here instead of silently
  // changing how the whole app looks. When an edit is intentional, update
  // the snapshot in the same commit.
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
    // MONOCHROME dark: near-black neutral surfaces, white accent, neutral
    // catch-light; status colors are brightness shades, not hues.
    expectGlassRamp(GlassTheme.dark, {
      'background': const Color(0xFF0A0A0A),
      'surface': const Color(0xC21B1B1B),
      'surfaceStrong': const Color(0xE8242424),
      'surfaceSubtle': const Color(0x7F282828),
      'floating': const Color(0xE62C2C2C),
      'border': const Color(0x12FFFFFF),
      'highlight': const Color(0x0FFFFFFF),
      'primary': const Color(0xFFFFFFFF),
      'primarySoft': const Color(0x14FFFFFF),
      'secondary': const Color(0xFFCCCCCC),
      'ai': const Color(0xFFF5F5F5),
      'audio': const Color(0xFFE6E6E6),
      'success': const Color(0xFFFFFFFF),
      'warning': const Color(0xFFCBCBCB),
      'danger': const Color(0xFFA3A3A3),
    });
    // MONOCHROME light: paper-family surfaces, black accent, gray-edged
    // glass; status colors are grays separated by brightness + icons.
    expectGlassRamp(GlassTheme.light, {
      'background': const Color(0xFFF5F5F5),
      'surface': const Color(0xE0FFFFFF),
      'surfaceStrong': const Color(0xF0FFFFFF),
      'surfaceSubtle': const Color(0xB3FFFFFF),
      'floating': const Color(0xECFFFFFF),
      'border': const Color(0x26000000),
      'highlight': const Color(0x59FFFFFF),
      'primary': const Color(0xFF000000),
      'primarySoft': const Color(0x12000000),
      'secondary': const Color(0xFF333333),
      'ai': const Color(0xFF111111),
      'audio': const Color(0xFF262626),
      'success': const Color(0xFF000000),
      'warning': const Color(0xFF3D3D3D),
      'danger': const Color(0xFF6B6B6B),
    });
    // M3 system ramps: dark steps the obsidian family, light the paper
    // family — no hue in either mode.
    expectSchemeRamp(buildAppTheme(Brightness.dark).colorScheme, {
      'surface': const Color(0xFF131313),
      'surfaceContainerLowest': const Color(0xFF0A0A0A),
      'surfaceContainerLow': const Color(0xFF0D0D0D),
      'surfaceContainer': const Color(0xFF131313),
      'surfaceContainerHigh': const Color(0xFF171717),
      'surfaceContainerHighest': const Color(0xFF1D1D1D),
    });
    expectSchemeRamp(buildAppTheme(Brightness.light).colorScheme, {
      'surface': const Color(0xFFFAFAFA),
      'surfaceContainerLowest': const Color(0xFFFFFFFF),
      'surfaceContainerLow': const Color(0xFFF4F4F4),
      'surfaceContainer': const Color(0xFFECECEC),
      'surfaceContainerHigh': const Color(0xFFE5E5E5),
      'surfaceContainerHighest': const Color(0xFFDEDEDE),
    });
  });

  // The atmosphere, locked the same way: every mood's light-field palette
  // (both accent tints + the blob alpha per mode) and the base-surface
  // blend (gradient weight + accent alpha per mode). Monochrome: moods
  // differ by brightness, never hue — dark fields are white/light-gray
  // light, light fields are gray shadows on paper. The ambient must not
  // drift silently either. Update the snapshot in the same commit as any
  // intentional atmosphere change.
  test('ambient atmosphere snapshot locks mood palettes and base blend', () {
    const moods = [
      BackgroundMood.ambient,
      BackgroundMood.study,
      BackgroundMood.ai,
      BackgroundMood.audio,
      BackgroundMood.premium,
    ];
    final expected =
        <BackgroundMood, Map<bool, ({Color a, Color b, double alpha})>>{
          BackgroundMood.ambient: {
            true: (
              a: const Color(0xFFFFFFFF),
              b: const Color(0xFFE6E6E6),
              alpha: 0.20,
            ),
            false: (
              a: const Color(0xFF9E9E9E),
              b: const Color(0xFFC9C9C9),
              alpha: 0.12,
            ),
          },
          BackgroundMood.study: {
            true: (
              a: const Color(0xFFFFFFFF),
              b: const Color(0xFFBDBDBD),
              alpha: 0.20,
            ),
            false: (
              a: const Color(0xFF9E9E9E),
              b: const Color(0xFFA6A6A6),
              alpha: 0.12,
            ),
          },
          BackgroundMood.ai: {
            true: (
              a: const Color(0xFFFFFFFF),
              b: const Color(0xFFCCCCCC),
              alpha: 0.22,
            ),
            false: (
              a: const Color(0xFF9E9E9E),
              b: const Color(0xFF7A7A7A),
              alpha: 0.14,
            ),
          },
          BackgroundMood.audio: {
            true: (
              a: const Color(0xFFE6E6E6),
              b: const Color(0xFFA6A6A6),
              alpha: 0.24,
            ),
            false: (
              a: const Color(0xFFC9C9C9),
              b: const Color(0xFF666666),
              alpha: 0.14,
            ),
          },
          BackgroundMood.premium: {
            true: (
              a: const Color(0xFFFFFFFF),
              b: const Color(0xFFCCCCCC),
              alpha: 0.20,
            ),
            false: (
              a: const Color(0xFF9E9E9E),
              b: const Color(0xFF7A7A7A),
              alpha: 0.12,
            ),
          },
        };
    for (final mood in moods) {
      for (final dark in [true, false]) {
        final mode = dark ? 'dark' : 'light';
        final p = ambientPalette(mood, dark: dark);
        final e = expected[mood]![dark]!;
        expect(p.a, e.a, reason: 'ambient $mood $mode accent a');
        expect(p.b, e.b, reason: 'ambient $mood $mode accent b');
        expect(p.alpha, e.alpha, reason: 'ambient $mood $mode blob alpha');
      }
    }
    expect(kAmbientBaseWeightDark, 0.10, reason: 'dark base gradient weight');
    expect(kAmbientBaseWeightLight, 0.04, reason: 'light base gradient weight');
    expect(kAmbientBaseAccentAlphaDark, 0.50, reason: 'dark base accent alpha');
    expect(
      kAmbientBaseAccentAlphaLight,
      0.30,
      reason: 'light base accent alpha',
    );
  });
}
