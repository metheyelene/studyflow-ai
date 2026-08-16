import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/performance/device_tier.dart';
import '../../../core/theme/app_theme.dart';

/// Context mood for the ambient background. Each mood shifts the tint and
/// weight of the light fields so the atmosphere quietly matches what the
/// user is doing — AI work glows cyan, study a teal/emerald wash, audio a
/// warm coral field, Premium a golden sheen. Mood changes cross-fade over
/// [kAtmosphereTransition] — a finite tween, so `pumpAndSettle` still
/// settles (no infinite drift loop) while the atmosphere eases between
/// contexts instead of snapping.
enum BackgroundMood { ambient, study, ai, audio, premium }

/// How long a mood change takes to cross-fade the atmosphere. Slow on
/// purpose — this is the ambient environment, not a UI state change.
const Duration kAtmosphereTransition = Duration(milliseconds: 900);

/// The flat low-tier fallback surface (keyed so tests can assert the
/// ambient layer is swapped out).
const kStudyFlowBackgroundBase = Key('studyflow-bg-base');

/// The ambient light-field layer (keyed so tests can assert it is present
/// on the standard tier and absent on the low tier).
const kStudyFlowBackgroundBlobs = Key('studyflow-bg-blobs');

/// How much the mood accent leans into the base-surface gradient at the
/// bottom of the canvas, and at what accent alpha. Dark blends 10% toward
/// the accent at half opacity; light uses a quarter of that weight (4%)
/// because a tint shift is far more visible on white — the canvas must
/// stay black-dominant / paper-dominant in both modes, with the visible
/// color living in the light fields. Exported so the atmosphere is locked
/// by the token snapshot test.
const double kAmbientBaseWeightDark = 0.10;
const double kAmbientBaseWeightLight = 0.04;
const double kAmbientBaseAccentAlphaDark = 0.50;
const double kAmbientBaseAccentAlphaLight = 0.30;

/// The two accent tints + light-field alpha for a mood. Alphas stay low
/// (≤0.20 light, ≤0.24 dark) so text contrast on top is unaffected.
/// Top-level so the atmosphere tokens are testable — the widget calls this
/// and the snapshot test locks it.
({Color a, Color b, double alpha}) ambientPalette(
  BackgroundMood mood, {
  required bool dark,
}) {
  final a = dark ? 0.20 : 0.12;
  return switch (mood) {
    BackgroundMood.ambient => (
      a: const Color(0xFF0F766E),
      b: const Color(0xFF06B6D4),
      alpha: a,
    ),
    BackgroundMood.study => (
      a: const Color(0xFF0F766E),
      b: const Color(0xFF10B981),
      alpha: a,
    ),
    BackgroundMood.ai => (
      a: const Color(0xFF22D3EE),
      b: const Color(0xFF3B82F6),
      alpha: dark ? 0.22 : 0.14,
    ),
    BackgroundMood.audio => (
      a: const Color(0xFFFB7185),
      b: const Color(0xFFF59E0B),
      alpha: dark ? 0.24 : 0.14,
    ),
    BackgroundMood.premium => (
      a: const Color(0xFFF59E0B),
      b: const Color(0xFFFB7185),
      alpha: a,
    ),
  };
}

/// Layered ambient background: base surface + soft color fields, with
/// content on top. Purely decorative — blobs are IgnorePointer with no
/// semantics — so it can wrap any screen without affecting interaction.
/// On the low performance tier the ambient layer is disabled entirely and
/// the base flattens to a solid fill: every blob and gradient is a shader
/// pass, and low-end GPUs win by skipping them.
class StudyFlowBackground extends ConsumerWidget {
  const StudyFlowBackground({
    super.key,
    required this.child,
    this.mood = BackgroundMood.ambient,
  });

  final Widget child;
  final BackgroundMood mood;

  ({Color a, Color b, double alpha}) _palette(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ambientPalette(mood, dark: dark);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    if (ref.watch(performanceTierProvider) == PerformanceTier.low) {
      // Low-end tier: solid background, no ambient fields, no sheen.
      return DecoratedBox(
        key: kStudyFlowBackgroundBase,
        decoration: BoxDecoration(color: g.background),
        child: child,
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _palette(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Mood changes cross-fade the whole atmosphere. Finite, so it
        // settles in tests; the old palette lingers during the fade, which
        // is exactly the slow atmospheric shift the design calls for.
        AnimatedSwitcher(
          duration: kAtmosphereTransition,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(mood),
            child: SizedBox.expand(
              child: _ambientLayers(context: context, dark: dark, p: p),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _ambientLayers({
    required BuildContext context,
    required bool dark,
    required ({Color a, Color b, double alpha}) p,
  }) {
    final g = context.glass;
    Widget blob({
      required Alignment alignment,
      required double size,
      required Color color,
      double opacity = 1,
    }) {
      return Align(
        alignment: alignment,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: p.alpha * opacity),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base surface: the canvas stays dominant in both modes — obsidian
        // black with a whisper of the mood tint in dark, near-white paper
        // with an even fainter hint in light (a tint shift is far more
        // visible on white, so light uses a quarter of dark's blend). The
        // visible color lives in the light fields below, which read as
        // light illuminating the environment instead of a color wash.
        DecoratedBox(
          decoration: BoxDecoration(
            color: g.background,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                g.background,
                Color.lerp(
                  g.background,
                  p.a.withValues(
                    alpha: dark
                        ? kAmbientBaseAccentAlphaDark
                        : kAmbientBaseAccentAlphaLight,
                  ),
                  dark ? kAmbientBaseWeightDark : kAmbientBaseWeightLight,
                )!,
              ],
            ),
          ),
        ),
        // Ambient light fields.
        LayoutBuilder(
          key: kStudyFlowBackgroundBlobs,
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                blob(
                  alignment: Alignment(-0.9, -0.95),
                  size: w * 0.85,
                  color: p.a,
                ),
                blob(
                  alignment: Alignment(1.05, -0.35),
                  size: w * 0.6,
                  color: p.b,
                  opacity: 0.8,
                ),
                blob(
                  alignment: Alignment(-0.4, 1.15),
                  size: w * 0.75,
                  color: p.b,
                  opacity: 0.55,
                ),
                // Faint top sheen so the glass reads against the light.
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: Container(
                      height: h * 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.03
                                  : 0.06,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
