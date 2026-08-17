/// Ambient and progress graphics: knowledge networks, the progress ring,
/// the audio waveform, mastery rings, streak marks, and the splash
/// sequence. These carry extremely subtle idle motion — the interface
/// stays calm, but alive.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sf_graphic_base.dart';

/// The abstract knowledge structure: dots, thin links, and arcs that
/// slowly connect and reorganize. Reusable in Study Space, AI, search,
/// processing, and empty states.
class SFKnowledgeGraphic extends StatelessWidget {
  const SFKnowledgeGraphic({
    super.key,
    this.size = const Size(120, 120),
    this.nodeCount = 7,
    this.paused = false,
  });

  final Size size;
  final int nodeCount;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _KnowledgePainter(t, p, nodeCount),
    );
  }
}

class _KnowledgePainter extends CustomPainter {
  _KnowledgePainter(this.t, this.p, this.nodeCount);

  final double t;
  final SFGraphicPalette p;
  final int nodeCount;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Nodes on a gentle ring with slight per-node drift.
    final nodes = List.generate(nodeCount, (i) {
      final a = (i / nodeCount) * 2 * math.pi;
      final drift = 0.06 * math.sin(t * 2 * math.pi + i * 1.7);
      final r = size.width * 0.36 * (1 + drift);
      return c + Offset(math.cos(a), math.sin(a)) * r;
    });

    // Links that connect/disconnect slowly (each link breathes).
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final dist = ((i - j).abs()).toDouble();
        final breathe =
            0.5 + 0.5 * math.sin(t * 2 * math.pi * 0.8 + i * 2.1 + j);
        final alpha = dist <= 1 ? 0.45 * breathe : 0.16 * breathe;
        canvas.drawLine(
          nodes[i],
          nodes[j],
          stroke..color = p.faint.withValues(alpha: alpha),
        );
      }
    }

    // Nodes: idle dots, one bright "active knowledge" pulse rotating.
    for (var i = 0; i < nodes.length; i++) {
      final active = ((t * nodeCount) % nodeCount).floor() == i;
      fill.color = active ? p.strong : p.line.withValues(alpha: 0.4);
      canvas.drawCircle(nodes[i], active ? kSfDot * 2.4 : kSfDot * 1.7, fill);
    }

    // Central node — the learner.
    fill.color = p.strong;
    canvas.drawCircle(c, kSfDot * 2.6, fill);
    stroke.color = p.strong.withValues(alpha: 0.3 + 0.25 * SFPhase.pulse(t));
    canvas.drawCircle(c, kSfDot * 4.2 + 1.5 * SFPhase.pulse(t), stroke);
  }

  @override
  bool shouldRepaint(covariant _KnowledgePainter old) =>
      old.t != t || old.nodeCount != nodeCount;
}

/// A thin progress ring that fills, with a tiny highlight traveling the
/// rim — the mastery/progress moment.
class SFProgressRingGraphic extends StatelessWidget {
  const SFProgressRingGraphic({
    super.key,
    this.size = const Size(64, 64),
    this.progress = 0.72,
    this.paused = false,
  });

  final Size size;

  /// 0..1 — the ring's filled fraction.
  final double progress;

  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _RingPainter(t, p, progress),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.p, this.progress);

  final double t;
  final SFGraphicPalette p;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Track.
    stroke.color = p.faint.withValues(alpha: 0.35);
    canvas.drawCircle(c, r, stroke);

    // Fill.
    final filled = (progress).clamp(0.0, 1.0);
    stroke.color = p.strong;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      filled * 2 * math.pi,
      false,
      stroke,
    );

    // Traveling highlight dot on the rim.
    final a = -math.pi / 2 + t * 2 * math.pi;
    final dot = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(
      dot,
      kSfDot * 1.6,
      Paint()..color = p.line.withValues(alpha: 0.9),
    );

    // Soft leading edge of the fill.
    if (filled > 0) {
      final edge =
          c +
          Offset(
                math.cos(-math.pi / 2 + filled * 2 * math.pi),
                math.sin(-math.pi / 2 + filled * 2 * math.pi),
              ) *
              r;
      canvas.drawCircle(edge, kSfDot * 1.3, Paint()..color = p.strong);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.t != t || old.progress != progress;
}

/// An elegant waveform that stills when paused and moves subtly while
/// playing. Amplitude bars, not equalizer blocks.
class SFAudioWaveform extends StatelessWidget {
  const SFAudioWaveform({
    super.key,
    this.size = const Size(160, 48),
    this.playing = true,
    this.barCount = 24,
    this.paused = false,
  });

  final Size size;
  final bool playing;
  final int barCount;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _WaveformPainter(t, p, playing, barCount),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.t, this.p, this.playing, this.barCount);

  final double t;
  final SFGraphicPalette p;
  final bool playing;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = p.line
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final gap = size.width / (barCount + 1);
    for (var i = 0; i < barCount; i++) {
      final x = gap * (i + 1);
      // Base profile: taller in the middle, tapering at the ends.
      final mid = 1 - (i - barCount / 2).abs() / (barCount / 2);
      final idle = 0.12 + 0.2 * mid;
      // Playing: per-bar gentle amplitude.
      final amp = playing
          ? idle +
                0.30 * mid * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 0.9))
          : idle;
      final half = size.height * 0.5 * amp;
      final alpha = 0.25 + 0.75 * (0.3 + 0.7 * mid);
      paint.color = p.line.withValues(alpha: alpha);
      canvas.drawLine(
        Offset(x, size.height / 2 - half),
        Offset(x, size.height / 2 + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.t != t || old.playing != playing;
}

/// Knowledge mastery: concentric rings, one per mastered topic — each
/// ring a layer of understanding. Brightness carries the level.
class SFMasteryGraphic extends StatelessWidget {
  const SFMasteryGraphic({
    super.key,
    this.size = const Size(96, 96),
    this.rings = 4,
    this.level = 0.72,
    this.paused = false,
  });

  final Size size;
  final int rings;
  final double level;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _MasteryPainter(t, p, rings, level),
    );
  }
}

class _MasteryPainter extends CustomPainter {
  _MasteryPainter(this.t, this.p, this.rings, this.level);

  final double t;
  final SFGraphicPalette p;
  final int rings;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    final mastered = (rings * level).ceil();
    for (var i = 0; i < rings; i++) {
      final r = size.width * 0.16 * (i + 1);
      final isMastered = i < mastered;
      final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 0.7 + i * 1.3);
      stroke.color = isMastered
          ? p.strong.withValues(alpha: 0.55 + 0.35 * breathe)
          : p.faint.withValues(alpha: 0.3);
      canvas.drawCircle(c, r, stroke);
    }

    // Core dot.
    canvas.drawCircle(c, kSfDot * 2.2, Paint()..color = p.strong);
  }

  @override
  bool shouldRepaint(covariant _MasteryPainter old) =>
      old.t != t || old.rings != rings || old.level != level;
}

/// Streak: calendar geometry — stacked dots/lines; each completed day
/// adds a bright mark.
class SFStreakGraphic extends StatelessWidget {
  const SFStreakGraphic({
    super.key,
    this.size = const Size(120, 44),
    this.days = 7,
    this.done = 4,
    this.paused = false,
  });

  final Size size;
  final int days;
  final int done;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _StreakPainter(t, p, days, done),
    );
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter(this.t, this.p, this.days, this.done);

  final double t;
  final SFGraphicPalette p;
  final int days;
  final int done;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final gap = size.width / (days + 1);
    for (var i = 0; i < days; i++) {
      final x = gap * (i + 1);
      final isDone = i < done;
      final pop = isDone ? SFPhase.pulse(t * 0.7 + i * 0.4) : 0.0;
      final r = kSfDot * (isDone ? 1.8 + 0.6 * pop : 1.2);
      fill.color = isDone
          ? p.strong.withValues(alpha: 0.55 + 0.45 * pop)
          : p.faint.withValues(alpha: 0.35);
      canvas.drawCircle(Offset(x, size.height / 2), r, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter old) =>
      old.t != t || old.done != done;
}

/// Splash: a thin line draws itself, grows into a small knowledge
/// structure, which collapses into the StudyFlow mark. One short beat.
class SFSplashGraphic extends StatelessWidget {
  const SFSplashGraphic({
    super.key,
    this.size = const Size(140, 140),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration:
          AppMotion.graphicsReveal + const Duration(milliseconds: 400),
      paint: (t, p) => _SplashPainter(t, p),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight * 1.2
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // 1. The line draws itself (0–0.35).
    final lineDraw = Curves.easeOut.transform((t / 0.35).clamp(0, 1));
    stroke.color = p.line;
    canvas.drawLine(
      Offset(c.dx - size.width * 0.3, c.dy),
      Offset(c.dx - size.width * 0.3 + size.width * 0.6 * lineDraw, c.dy),
      stroke,
    );

    // 2. The line sprouts a knowledge structure (0.35–0.75).
    final grow = Curves.easeOut.transform(((t - 0.35) / 0.4).clamp(0, 1));
    if (grow > 0) {
      const pts = [
        Offset(-0.10, -0.22),
        Offset(0.10, -0.18),
        Offset(-0.06, 0.02),
        Offset(0.12, 0.16),
        Offset(-0.14, 0.20),
      ];
      for (var i = 0; i < pts.length; i++) {
        final n = c + pts[i] * size.width * grow;
        final on = SFPhase.on(grow, i, pts.length, spread: 0.5);
        if (on <= 0) continue;
        canvas.drawLine(
          c + pts[i] * size.width * grow * (1 - 0.35 * (1 - on)),
          n,
          stroke..color = p.faint.withValues(alpha: on),
        );
        fill.color = p.line.withValues(alpha: 0.3 + 0.7 * on);
        canvas.drawCircle(n, kSfDot * 1.6, fill);
      }
    }

    // 3. It collapses back into the mark (0.75–1).
    final collapse = Curves.easeIn.transform(((t - 0.75) / 0.25).clamp(0, 1));
    if (collapse > 0) {
      final scale = 1 - 0.85 * collapse;
      canvas.drawCircle(
        c,
        kSfDot * 2.6 * scale,
        fill..color = p.strong.withValues(alpha: 1 - 0.4 * collapse),
      );
    } else {
      fill.color = p.strong.withValues(alpha: grow > 0.9 ? 0.4 : 0.9);
      canvas.drawCircle(c, kSfDot * 2.6, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => old.t != t;
}
