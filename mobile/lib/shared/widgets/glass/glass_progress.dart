import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Translucent linear progress with a track tinted by the accent.
class GlassProgress extends StatelessWidget {
  const GlassProgress({
    super.key,
    required this.value,
    this.height = 8,
  });

  /// 0–1.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: g.primary.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation(g.primary),
      ),
    );
  }
}

/// Circular progress ring (used for the AI-usage meter on the dashboard).
class GlassRing extends StatelessWidget {
  const GlassRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 84,
    this.strokeWidth = 7,
  });

  /// 0–1.
  final double value;
  final String label;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: g.textPrimary.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(g.primary),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: g.textPrimary,
              fontSize: size * 0.19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
