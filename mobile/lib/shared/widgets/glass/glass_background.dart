import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Context mood for the ambient background. Each mood shifts the tint and
/// weight of the light fields so the atmosphere quietly matches what the
/// user is doing — AI work glows cool indigo, audio gets a deeper media
/// wash, Premium a warmer sheen. The mood never animates: static radial
/// gradients are GPU-cheap and keep tests deterministic (an infinite
/// drift loop would hang every `pumpAndSettle`).
enum BackgroundMood { ambient, study, ai, audio, premium }

/// Layered ambient background: base surface + soft color fields, with
/// content on top. Purely decorative — blobs are IgnorePointer with no
/// semantics — so it can wrap any screen without affecting interaction.
class StudyFlowBackground extends StatelessWidget {
  const StudyFlowBackground({
    super.key,
    required this.child,
    this.mood = BackgroundMood.ambient,
  });

  final Widget child;
  final BackgroundMood mood;

  /// Two accent tints per mood: primary + a companion hue. Alphas stay low
  /// (≤0.20 light, ≤0.24 dark) so text contrast on top is unaffected.
  ({Color a, Color b, double alpha}) _palette(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = dark ? 0.20 : 0.12;
    return switch (mood) {
      BackgroundMood.ambient => (
        a: const Color(0xFF6366F1),
        b: const Color(0xFF8B5CF6),
        alpha: a,
      ),
      BackgroundMood.study => (
        a: const Color(0xFF6366F1),
        b: const Color(0xFF14B8A6),
        alpha: a,
      ),
      BackgroundMood.ai => (
        a: const Color(0xFF818CF8),
        b: const Color(0xFFA78BFA),
        alpha: dark ? 0.22 : 0.14,
      ),
      BackgroundMood.audio => (
        a: const Color(0xFF6366F1),
        b: const Color(0xFF312E81),
        alpha: dark ? 0.24 : 0.14,
      ),
      BackgroundMood.premium => (
        a: const Color(0xFF6366F1),
        b: const Color(0xFFF59E0B),
        alpha: a,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _palette(context);

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
        // Base surface.
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
                  p.a.withValues(alpha: dark ? 0.5 : 0.35),
                  0.5,
                )!,
              ],
            ),
          ),
        ),
        // Ambient light fields.
        LayoutBuilder(
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
                              alpha: Theme.of(context).brightness ==
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
        child,
      ],
    );
  }
}
