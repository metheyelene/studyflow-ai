/// AI lifecycle graphics: THOUGHT → STRUCTURE → ANSWER.
///
/// [SFAIThinkingGraphic] is the signature StudyFlow thinking mark — a
/// small circle whose internal geometry (thin arcs, orbiting dots) slowly
/// reorganizes, like information being processed. [SFAIGeneratingGraphic]
/// grows a dense line structure representing an answer taking shape.
/// [SFSourceSearchGraphic] shows sources being retrieved: a node network
/// where a pulse travels between nodes and relevant ones brighten.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sf_graphic_base.dart';

/// Abstract thinking mark: a circle with rotating thin arcs and a few
/// orbiting dots. No robot, no brain, no sparkles.
class SFAIThinkingGraphic extends StatelessWidget {
  const SFAIThinkingGraphic({
    super.key,
    this.size = const Size(64, 64),
    this.active = true,
    this.paused = false,
  });

  final Size size;
  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: active ? AppMotion.graphicsBusy : AppMotion.graphicsLoop,
      paint: (t, p) => _ThinkingPainter(t, p, active),
    );
  }
}

class _ThinkingPainter extends CustomPainter {
  _ThinkingPainter(this.t, this.p, this.active);

  final double t;
  final SFGraphicPalette p;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.36;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Outer ring.
    stroke.color = p.faint.withValues(alpha: 0.7);
    canvas.drawCircle(c, r, stroke);

    // Three thin arcs rotating slowly (one at a time in sequence).
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final start = phase * 2 * math.pi;
      final sweep = 0.9 + 0.8 * SFPhase.pulse(phase);
      final arcR = r * 0.62;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        start,
        sweep * (active ? 1.0 : 0.35),
        false,
        stroke
          ..color = p.line.withValues(
            alpha: 0.35 + 0.65 * SFPhase.pulse(phase),
          ),
      );
    }

    // A waveform seam across the core — information passing through.
    final wave = Path();
    for (var i = 0; i <= 12; i++) {
      final x = c.dx - r * 0.55 + (r * 1.1) * i / 12;
      final y =
          c.dy +
          3 *
              math.sin((i / 12) * 2 * math.pi + t * 2 * math.pi) *
              (active ? 1 : 0.3);
      if (i == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(wave, stroke..color = p.faint.withValues(alpha: 0.8));

    // Orbiting dots — two small particles travelling the ring.
    if (active) {
      for (var i = 0; i < 2; i++) {
        final a = t * 2 * math.pi + i * math.pi;
        final pos = c + Offset(math.cos(a), math.sin(a)) * r;
        fill.color = p.strong.withValues(alpha: 0.9);
        canvas.drawCircle(pos, kSfDot * 1.3, fill);
      }
    }

    // Center dot.
    fill.color = p.strong;
    canvas.drawCircle(c, kSfDot * 2, fill);
  }

  @override
  bool shouldRepaint(covariant _ThinkingPainter old) =>
      old.t != t || old.active != active;
}

/// Generating: small horizontal lines appear, change length, and the
/// structure grows denser — an answer taking shape.
class SFAIGeneratingGraphic extends StatelessWidget {
  const SFAIGeneratingGraphic({
    super.key,
    this.size = const Size(72, 56),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsBusy,
      paint: (t, p) => _GeneratingPainter(t, p),
    );
  }
}

class _GeneratingPainter extends CustomPainter {
  _GeneratingPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    const n = 6;
    final gap = size.height / (n + 1);
    for (var i = 0; i < n; i++) {
      final phase = (t * 1.4 + i * 0.18) % 1.0;
      final len =
          size.width *
          (0.35 + 0.55 * (0.5 + 0.5 * math.sin(phase * math.pi * 2)));
      final y = gap * (i + 1);
      // Section structure: lines 0–2 shorter (heading), 3–5 longer (body).
      final maxLen = size.width * (i < 2 ? 0.5 : 0.92);
      final w = math.min(len, maxLen);
      canvas.drawLine(
        Offset(size.width / 2 - w / 2, y),
        Offset(size.width / 2 + w / 2, y),
        paint
          ..color = p.line.withValues(alpha: 0.5 + 0.5 * SFPhase.pulse(phase)),
      );
    }

    // A bright leading dot sweeps the lines — thought becoming words.
    final leadY = gap * (1 + ((t * 6) % n).floor());
    final leadX = size.width / 2 + size.width * 0.3 * math.sin(t * math.pi * 2);
    final fill = Paint()..color = p.strong;
    canvas.drawCircle(Offset(leadX, leadY), kSfDot * 1.4, fill);
  }

  @override
  bool shouldRepaint(covariant _GeneratingPainter old) => old.t != t;
}

/// Source retrieval: a small node network where a pulse travels between
/// source nodes, brightening them, then converges on the center — SOURCES
/// → RETRIEVAL → ANSWER.
class SFSourceSearchGraphic extends StatelessWidget {
  const SFSourceSearchGraphic({
    super.key,
    this.size = const Size(96, 96),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsBusy,
      paint: (t, p) => _SourceSearchPainter(t, p),
    );
  }
}

class _SourceSearchPainter extends CustomPainter {
  _SourceSearchPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  static const _nodePos = [
    Offset(-0.30, -0.26),
    Offset(0.30, -0.22),
    Offset(0.02, -0.38),
    Offset(-0.34, 0.10),
    Offset(0.34, 0.12),
    Offset(0.0, 0.34),
    Offset(-0.16, -0.04),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    final nodes = _nodePos.map((o) => c + o * size.width * 0.95).toList();

    // Idle links.
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if ((i + j) % 3 == 0) continue;
        canvas.drawLine(
          nodes[i],
          nodes[j],
          stroke..color = p.faint.withValues(alpha: 0.22),
        );
      }
    }

    // Traveling pulse visits each node in turn.
    final phase = (t * nodes.length) % nodes.length;
    final idx = phase.floor();
    final frac = phase - idx;
    final from = nodes[idx];
    final to = nodes[(idx + 1) % nodes.length];
    final pulsePos = Offset.lerp(from, to, Curves.easeInOut.transform(frac))!;

    fill.color = p.strong.withValues(alpha: 0.9);
    canvas.drawCircle(pulsePos, kSfDot * 1.7, fill);

    // Nodes brighten as the pulse reaches them.
    for (var i = 0; i < nodes.length; i++) {
      final dist = (i - idx).abs();
      final visited = dist <= 0 || (idx == 0 && i == nodes.length - 1);
      final bright = i == idx
          ? 0.9
          : i == (idx + 1) % nodes.length
          ? 0.55
          : visited
          ? 0.35
          : 0.14;
      fill.color = p.line.withValues(alpha: bright);
      canvas.drawCircle(nodes[i], kSfDot * 2.4, fill);
    }

    // Center AI node.
    fill.color = p.strong;
    canvas.drawCircle(c, kSfDot * 2.6, fill);
    stroke.color = p.strong.withValues(alpha: 0.35 + 0.3 * SFPhase.pulse(t));
    canvas.drawCircle(c, kSfDot * 3.8 + 1.2 * SFPhase.pulse(t), stroke);
  }

  @override
  bool shouldRepaint(covariant _SourceSearchPainter old) => old.t != t;
}
