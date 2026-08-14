import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Translucent material card. By default there is NO per-card blur —
/// the fill is translucent with a subtle border + inset highlight and
/// layered shadows (cheap on GPU). Use [GlassCard.blurred] only for the
/// navigation shell, sheets, and modals, where blur earns its cost.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.tone = GlassTone.surface,
    this.radius = GlassTheme.radiusCard,
    this.blurred = false,
    this.color,
    this.glossy = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final GlassTone tone;
  final double radius;
  final bool blurred;
  final Color? color;

  /// Specular finish for hero surfaces: a stronger diagonal sheen, a
  /// brighter top edge, and a faint bottom reflection. Purely gradients —
  /// no extra blur, so heroes stay GPU-cheap.
  final bool glossy;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final fill =
        color ??
        switch (tone) {
          GlassTone.surface => g.surface,
          GlassTone.surfaceStrong => g.surfaceStrong,
          GlassTone.surfaceSubtle => g.surfaceSubtle,
          GlassTone.floating => g.floating,
        };

    final sheen = glossy ? 1.0 : 0.75;
    final container = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: fill,
        border: Border.all(color: g.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (glossy)
            BoxShadow(
              color: g.primary.withValues(alpha: 0.10),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: DecoratedBox(
        // Specular finish: diagonal light sweep + a brighter top edge
        // (a literal top border reads as a thin glass lip).
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border(
            top: BorderSide(
              color: g.highlight.withValues(alpha: 0.55 * sheen),
              width: 1.2,
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: glossy
                ? [
                    g.highlight.withValues(alpha: 0.9),
                    g.highlight.withValues(alpha: 0.25),
                    Colors.transparent,
                  ]
                : [g.highlight, Colors.transparent],
            stops: glossy ? const [0, 0.28, 0.5] : const [0, 0.45],
          ),
        ),
        child: DecoratedBox(
          // Faint bottom reflection so the surface reads as physical.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topCenter,
              colors: [
                g.primary.withValues(alpha: glossy ? 0.05 : 0.0),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final surface = blurred
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: g.blurRadius,
                sigmaY: g.blurRadius,
              ),
              child: container,
            ),
          )
        : container;

    if (onTap == null) return surface;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: surface),
    );
  }
}

enum GlassTone { surface, surfaceStrong, surfaceSubtle, floating }
