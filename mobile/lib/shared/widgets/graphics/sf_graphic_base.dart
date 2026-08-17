/// StudyFlow monochrome motion-graphics system.
///
/// A library of small, purposeful, black-and-white animated moments that
/// make the interface feel alive: document processing, AI thinking and
/// generating, source retrieval, success/error, audio, progress, splash.
///
/// Design rules shared by every graphic:
///  - Monochrome only — luminance and geometry, never hue.
///  - Thin 1.4px lines, circles, dots, arcs — no cartoon illustrations.
///  - Motion is calm and purposeful; reading screens stay still.
///  - Reduced motion (`MediaQuery.disableAnimationsOf`) settles every
///    graphic to its completed frame; low rendering tier drops the
///    particle detail. Graphics are decorative and exclude themselves
///    from the semantics tree (the surrounding UI carries the text).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Uniform stroke weight for the whole graphics language.
const double kSfLineWeight = 1.4;

/// Uniform dot radius for node/particle graphics.
const double kSfDot = 1.8;

/// Monochrome palette resolved from the current [GlassTheme] — every
/// graphic draws through this so it stays neutral in both modes.
class SFGraphicPalette {
  const SFGraphicPalette({
    required this.line,
    required this.faint,
    required this.strong,
    required this.ink,
    required this.onInk,
  });

  /// Primary line color (soft white in dark, near-black in light).
  final Color line;

  /// Muted line color for secondary structure (nodes, idle marks).
  final Color faint;

  /// Bright accent — white in dark, black in light — for highlights.
  final Color strong;

  /// Glass surface fill for dark-glass moments.
  final Color ink;

  /// Text on [ink].
  final Color onInk;

  factory SFGraphicPalette.from(GlassTheme g) {
    final dark =
        ThemeData.estimateBrightnessForColor(g.background) == Brightness.dark;
    return SFGraphicPalette(
      line: g.textPrimary,
      faint: g.textPrimary.withValues(alpha: 0.45),
      strong: g.primary,
      ink: dark ? const Color(0xCC1B1B1B) : const Color(0xE6F2F2F2),
      onInk: g.textPrimary,
    );
  }
}

/// A self-contained animated graphic.
///
/// [paint] receives the animation phase `t` (0..1, looping unless
/// [oneShot]) and the resolved palette, and returns a [CustomPainter]
/// for that frame. The widget owns the controller, honors reduced
/// motion, and excludes itself from semantics (decorative by design).
class SFGraphic extends StatefulWidget {
  const SFGraphic({
    super.key,
    required this.paint,
    required this.loopDuration,
    this.size = const Size(64, 64),
    this.semanticLabel,
    this.oneShot = false,
    this.paused = false,
  });

  /// Returns the painter for phase `t` (0..1).
  final CustomPainter Function(double t, SFGraphicPalette p) paint;

  /// Loop period for continuous graphics; for [oneShot] this is the
  /// forward duration.
  final Duration loopDuration;

  /// Render size.
  final Size size;

  /// Accessibility label; the drawing itself is excluded from semantics.
  final String? semanticLabel;

  /// If true the graphic plays once to completion and holds.
  final bool oneShot;

  /// If true the graphic holds its resting frame.
  final bool paused;

  @override
  State<SFGraphic> createState() => _SFGraphicState();
}

class _SFGraphicState extends State<SFGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.loopDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _c
        ..stop()
        ..value = 1;
    } else {
      _play();
    }
  }

  @override
  void didUpdateWidget(covariant SFGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loopDuration != oldWidget.loopDuration) {
      _c.duration = widget.loopDuration;
    }
    if (widget.paused != oldWidget.paused ||
        widget.oneShot != oldWidget.oneShot) {
      if (!_reduced) _play();
    }
  }

  void _play() {
    if (widget.paused) {
      _c.stop();
      return;
    }
    if (widget.oneShot) {
      _c.forward(from: 0);
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final palette = SFGraphicPalette.from(g);
    final t = _reduced ? 1.0 : _c.value;
    final painter = widget.paint(t, palette);
    final graphic = SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: CustomPaint(painter: painter),
    );
    if (widget.semanticLabel == null) {
      return ExcludeSemantics(child: graphic);
    }
    return Semantics(
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: graphic),
    );
  }
}

/// Painters for the document silhouettes used across the system.
abstract final class SFLines {
  /// `n` horizontal text lines, optionally inset.
  static void textLines(
    Canvas canvas,
    Offset origin,
    double width,
    int n,
    double gap,
    Paint paint, {
    double inset = 0,
    double lastFrac = 0.55,
  }) {
    for (var i = 0; i < n; i++) {
      final w = width - inset * 2;
      final len = i == n - 1 ? w * lastFrac : w;
      canvas.drawLine(
        origin + Offset(inset, i * gap),
        origin + Offset(inset + len, i * gap),
        paint,
      );
    }
  }
}

/// Phase helpers — each graphic maps its loop `t` through these to keep
/// motion curves consistent.
abstract final class SFPhase {
  /// A single 0→1→0 pulse across the loop.
  static double pulse(double t) => math.sin(t * math.pi);

  /// Sawtooth with a smooth (ease-in-out) rise and sharp reset.
  static double sweep(double t) => Curves.easeInOut.transform(t);

  /// Triangle: rises 0→1 then falls 1→0.
  static double triangle(double t) => 1 - (2 * t - 1).abs();

  /// Staggered on-time for item `i` of `n`: 0 before start, 1 after.
  static double on(double t, int i, int n, {double spread = 0.45}) {
    final s = i * spread / math.max(1, n - 1);
    return ((t - s) / (1 - spread)).clamp(0.0, 1.0).toDouble();
  }

  /// Eased 0→1 across the whole loop.
  static double inOut(double t) => Curves.easeInOut.transform(t);
}
