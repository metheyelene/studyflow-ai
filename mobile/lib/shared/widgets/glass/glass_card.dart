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
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final GlassTone tone;
  final double radius;
  final bool blurred;
  final Color? color;

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
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [g.highlight, Colors.transparent],
            stops: const [0, 0.45],
          ),
        ),
        child: Padding(padding: padding, child: child),
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
