/// Feedback graphics: subtle monochrome moments for completion,
/// interruption, syncing, saving, and searching. No confetti, no red,
/// no aggressive shake — thin lines and iconography carry the message.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sf_graphic_base.dart';

/// Success: a thin circle draws, briefly expands, a checkmark draws
/// itself, then the whole mark settles into the UI.
class SFSuccessGraphic extends StatelessWidget {
  const SFSuccessGraphic({
    super.key,
    this.size = const Size(72, 72),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      oneShot: true,
      loopDuration: AppMotion.graphicsSuccess,
      paint: (t, p) => _SuccessPainter(t, p),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Circle draws (0–0.45), brief expansion (0.45–0.6), settle (0.6–1).
    final draw = Curves.easeOut.transform((t / 0.45).clamp(0, 1));
    final expand = (t - 0.45) / 0.15;
    final settle = Curves.easeOut.transform((t - 0.6) / 0.4);
    final radius =
        r * (1 + 0.08 * math.sin(expand * math.pi)) * (0.9 + 0.1 * settle);
    stroke.color = p.line.withValues(alpha: 0.25 + 0.75 * draw);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      draw * 2 * math.pi,
      false,
      stroke,
    );

    // Checkmark draws itself (0.5–0.95).
    final check = Curves.easeOut.transform(((t - 0.5) / 0.45).clamp(0, 1));
    if (check > 0) {
      final path = Path()
        ..moveTo(c.dx - r * 0.4, c.dy)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.28)
        ..lineTo(c.dx + r * 0.5, c.dy - r * 0.28);
      final metrics = path.computeMetrics().first;
      canvas.drawPath(
        metrics.extractPath(0, metrics.length * check),
        stroke..color = p.strong,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter old) => old.t != t;
}

/// Error: a thin circle with a calm "!" — interruption without red.
class SFErrorGraphic extends StatelessWidget {
  const SFErrorGraphic({
    super.key,
    this.size = const Size(72, 72),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsSuccess,
      paint: (t, p) => _ErrorPainter(t, p),
    );
  }
}

class _ErrorPainter extends CustomPainter {
  _ErrorPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    final draw = Curves.easeOut.transform((t / 0.4).clamp(0, 1));
    stroke.color = p.line.withValues(alpha: 0.2 + 0.8 * draw);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      draw * 2 * math.pi,
      false,
      stroke,
    );

    // Calm "!" — no shake.
    final mark = Curves.easeOut.transform(((t - 0.35) / 0.3).clamp(0, 1));
    if (mark > 0) {
      final bar = Paint()
        ..color = p.line.withValues(alpha: mark)
        ..strokeWidth = kSfLineWeight
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx, c.dy - r * 0.30),
        Offset(c.dx, c.dy + r * 0.05),
        bar,
      );
      canvas.drawCircle(
        Offset(c.dx, c.dy + r * 0.32),
        kSfDot,
        Paint()..color = p.line.withValues(alpha: mark),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ErrorPainter old) => old.t != t;
}

/// Sync: two minimal arcs glide toward each other, merge into a ring,
/// then settle. A circular geometric loop, not a spinner.
class SFSyncGraphic extends StatelessWidget {
  const SFSyncGraphic({
    super.key,
    this.size = const Size(56, 56),
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
      paint: (t, p) => _SyncPainter(t, p),
    );
  }
}

class _SyncPainter extends CustomPainter {
  _SyncPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.32;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Two arcs approach (0–0.5), merge into a full ring (0.5–0.8), settle.
    final approach = SFPhase.inOut((t / 0.5).clamp(0, 1));
    final arcGap = 0.7 - 0.6 * approach; // radians between arc heads
    final gap = arcGap * math.pi;
    for (var side = 0; side < 2; side++) {
      final base = side * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        base + gap / 2,
        math.pi - gap,
        false,
        stroke..color = p.line.withValues(alpha: 0.55 + 0.45 * approach),
      );
    }

    // Merge flash: a small bright dot where the heads meet.
    final merge = ((t - 0.5) / 0.3).clamp(0.0, 1.0).toDouble();
    if (merge > 0 && merge < 1) {
      final a = merge * 2 * math.pi + math.pi;
      final pos = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
        pos,
        kSfDot * (1 + merge),
        Paint()..color = p.strong.withValues(alpha: 1 - merge),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SyncPainter old) => old.t != t;
}

/// Saving: a tiny dot slides into a minimal tray and the tray briefly
/// brightens. Deliberately quiet — saves are not celebrations.
class SFSavingGraphic extends StatelessWidget {
  const SFSavingGraphic({
    super.key,
    this.size = const Size(48, 48),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.micro,
      paint: (t, p) => _SavingPainter(t, p),
    );
  }
}

class _SavingPainter extends CustomPainter {
  _SavingPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Minimal tray (a floppy-disk / storage silhouette).
    final w = size.width * 0.52;
    final h = size.height * 0.46;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      const Radius.circular(4),
    );
    stroke.color = p.line.withValues(alpha: 0.7);
    canvas.drawRRect(rect, stroke);
    // Label line.
    canvas.drawLine(
      Offset(c.dx - w * 0.22, c.dy + h * 0.26),
      Offset(c.dx + w * 0.22, c.dy + h * 0.26),
      stroke..color = p.faint,
    );

    // Dot drops in (0–0.55), tray brightens (0.55–1).
    final drop = Curves.easeIn.transform((t / 0.55).clamp(0, 1));
    final dotY = c.dy - h * 0.55 + (h * 0.8) * drop;
    fill.color = p.strong.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(c.dx, dotY), kSfDot * 1.3, fill);

    final glow = ((t - 0.55) / 0.45).clamp(0, 1);
    stroke.color = p.strong.withValues(alpha: 0.3 + 0.6 * glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.outerRect.deflate(1.5),
        const Radius.circular(3),
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SavingPainter old) => old.t != t;
}

/// Search: a small magnifier glides across abstract lines and the
/// relevant line brightens to white — under ~1 second.
class SFSearchGraphic extends StatelessWidget {
  const SFSearchGraphic({
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
      paint: (t, p) => _SearchPainter(t, p),
    );
  }
}

class _SearchPainter extends CustomPainter {
  _SearchPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Abstract result lines.
    const n = 4;
    final lineGap = size.height / (n + 1);
    for (var i = 0; i < n; i++) {
      final y = lineGap * (i + 1);
      final active = (t * n).floor() % n == i;
      final phase = SFPhase.pulse((t * n) % 1.0 + i * 0.05);
      canvas.drawLine(
        Offset(size.width * 0.16, y),
        Offset(
          size.width * 0.16 +
              size.width * (i == 1 ? 0.6 : 0.45) * (0.8 + 0.2 * phase),
          y,
        ),
        stroke..color = active ? p.strong : p.faint.withValues(alpha: 0.5),
      );
    }

    // Magnifier lens gliding over the lines.
    final lensX =
        size.width * 0.62 + size.width * 0.18 * math.sin(t * math.pi * 2);
    final lensY = lineGap * (1.5 + 0.5 * math.sin(t * math.pi * 2 + 0.7));
    final lensR = size.height * 0.22;
    canvas.drawCircle(Offset(lensX, lensY), lensR, stroke..color = p.line);
    // Handle.
    canvas.drawLine(
      Offset(lensX + lensR * 0.7, lensY + lensR * 0.7),
      Offset(lensX + lensR * 1.3, lensY + lensR * 1.3),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchPainter old) => old.t != t;
}
