/// Document lifecycle graphics: FILE → READ → PROCESS → READY.
///
/// [SFDocumentScanGraphic] is a page silhouette with an elegant scanning
/// line that illuminates text rows as it passes — meaning PDF/DOC/PPT →
/// TEXT → KNOWLEDGE. [SFUploadGraphic] tells the whole story: a document
/// outline splits into lines, particles travel into a knowledge cluster,
/// and a checkmark draws itself.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sf_graphic_base.dart';

/// Document type the scan graphic represents.
enum SFDocumentKind { pdf, doc, ppt, image }

/// A minimal page silhouette with a vertical scanning line. As the line
/// passes, text rows illuminate from faint to bright; a soft halo trails
/// the scan edge. Monochrome, no laser effect.
class SFDocumentScanGraphic extends StatelessWidget {
  const SFDocumentScanGraphic({
    super.key,
    this.kind = SFDocumentKind.pdf,
    this.size = const Size(96, 120),
    this.paused = false,
  });

  final SFDocumentKind kind;
  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _ScanPainter(kind, t, p),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.kind, this.t, this.p);

  final SFDocumentKind kind;
  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Page silhouette.
    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.28,
        size.height * 0.06,
        size.width * 0.44,
        size.height * 0.88,
      ),
      const Radius.circular(6),
    );
    stroke.color = p.faint;
    canvas.drawRRect(page, stroke);

    // Content rows inside the page (kind-specific shapes).
    canvas.saveLayer(page.outerRect, Paint());
    canvas.clipRRect(page);
    final rowPaint = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    final x0 = page.left + size.width * 0.06;
    final x1 = page.right - size.width * 0.06;
    final y0 = page.top + size.height * 0.12;
    final rowGap = size.height * 0.09;

    if (kind == SFDocumentKind.ppt) {
      // Slide: title bar + two stacked frames.
      for (var i = 0; i < 3; i++) {
        final rect = Rect.fromLTWH(
          x0 + i * size.width * 0.02,
          y0 + i * size.height * 0.06,
          (x1 - x0),
          size.height * 0.2,
        );
        final alpha = SFPhase.on(t, i, 3) * 0.85 + 0.15;
        rowPaint.color = p.line.withValues(alpha: alpha);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          rowPaint..style = PaintingStyle.stroke,
        );
      }
      rowPaint.style = PaintingStyle.stroke;
    } else if (kind == SFDocumentKind.image) {
      // OCR: image frame with detected text segments appearing in a grid.
      final cols = 3;
      final rows = 3;
      for (var i = 0; i < cols * rows; i++) {
        final c = i % cols;
        final r = i ~/ cols;
        final cx = x0 + (x1 - x0) * (c + 0.5) / cols;
        final cy = y0 + rowGap * (r + 0.5);
        final on = SFPhase.on(t, i, cols * rows, spread: 0.6);
        if (on > 0) {
          final w = (x1 - x0) / cols * 0.6 * (0.4 + 0.6 * on);
          canvas.drawLine(
            Offset(cx - w / 2, cy),
            Offset(cx + w / 2, cy),
            rowPaint..color = p.line.withValues(alpha: on),
          );
        }
      }
    } else {
      // Document: text rows illuminate as the scan passes.
      final n = 7;
      for (var i = 0; i < n; i++) {
        final cy = y0 + i * rowGap;
        final on = ((t * size.height - (cy - page.top)) / (size.height * 0.2))
            .clamp(0.0, 1.0);
        final w = (x1 - x0) * (i == n - 1 ? 0.5 : 1.0);
        canvas.drawLine(
          Offset(x0, cy),
          Offset(x0 + w, cy),
          rowPaint..color = p.line.withValues(alpha: 0.15 + 0.85 * on),
        );
      }
    }

    // Elegant scan line with a soft trailing band (brightness, not glow).
    final scanY = page.top + size.height * 0.8 * SFPhase.sweep(t);
    final band = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              p.strong.withValues(alpha: 0.0),
              p.strong.withValues(alpha: 0.10),
            ],
          ).createShader(
            Rect.fromLTWH(
              page.left,
              scanY - size.height * 0.10,
              page.width,
              size.height * 0.12,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(
        page.left,
        scanY - size.height * 0.10,
        page.width,
        size.height * 0.12,
      ),
      band,
    );
    canvas.drawLine(
      Offset(page.left, scanY),
      Offset(page.right, scanY),
      Paint()
        ..color = p.strong
        ..strokeWidth = kSfLineWeight
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();

    // Page shadow — a short baseline tick for grounding.
    fill.color = p.faint.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.24,
          size.height * 0.97,
          size.width * 0.52,
          2,
        ),
        const Radius.circular(1),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) =>
      old.t != t || old.kind != kind;
}

/// The full upload story: a document outline appears, splits into lines,
/// lines rise, particles travel into a knowledge cluster, then a thin
/// checkmark draws itself. One 2.2s loop.
class SFUploadGraphic extends StatelessWidget {
  const SFUploadGraphic({
    super.key,
    this.size = const Size(120, 120),
    this.paused = false,
  });

  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _UploadPainter(t, p),
    );
  }
}

class _UploadPainter extends CustomPainter {
  _UploadPainter(this.t, this.p);

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

    // Phase timeline inside the loop:
    // 0.00–0.30 document outline draws
    // 0.30–0.55 document splits into rising lines + particles
    // 0.55–0.85 knowledge cluster assembles at top
    // 0.85–1.00 checkmark draws
    final docW = size.width * 0.3;
    final docH = size.height * 0.34;
    final docTop = c.dy + size.height * 0.12;
    final docLeft = c.dx - docW / 2;

    final drawDoc = (t - 0) / 0.3;
    if (drawDoc > 0) {
      stroke.color = p.line.withValues(alpha: SFPhase.inOut(drawDoc));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(docLeft, docTop, docW, docH),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, stroke);
      // Header line.
      canvas.drawLine(
        Offset(docLeft + docW * 0.16, docTop + docH * 0.16),
        Offset(docLeft + docW * 0.84, docTop + docH * 0.16),
        stroke,
      );
      // Content lines.
      final linePaint = Paint()
        ..color = p.faint
        ..strokeWidth = kSfLineWeight
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final ly = docTop + docH * (0.34 + i * 0.14);
        canvas.drawLine(
          Offset(docLeft + docW * 0.16, ly),
          Offset(docLeft + docW * (i == 3 ? 0.5 : 0.84), ly),
          linePaint,
        );
      }
    }

    // Rising lines + particles toward the knowledge cluster.
    final split = ((t - 0.30) / 0.25).clamp(0.0, 1.0);
    final rise = Curves.easeOut.transform(split);
    if (rise > 0) {
      final clusterC = Offset(c.dx, c.dy - size.height * 0.28);
      for (var i = 0; i < 5; i++) {
        final startY = docTop + docH * (0.34 + i * 0.12);
        final targetY = clusterC.dy - size.height * 0.06 + i * 4;
        final ly = startY + (targetY - startY) * rise;
        final alpha = 0.9 - i * 0.08;
        canvas.drawLine(
          Offset(docLeft + docW * 0.16, ly),
          Offset(docLeft + docW * 0.84, ly),
          stroke..color = p.line.withValues(alpha: alpha * (1 - rise * 0.5)),
        );
        // Particle.
        final pr = 0.35 + 0.65 * rise;
        final px = docLeft + docW * (0.3 + 0.4 * (i % 3) / 2);
        final py = startY + (targetY - startY) * pr + 6 * math.sin(t * 6 + i);
        fill.color = p.strong.withValues(alpha: (1 - pr) * 0.9 + 0.1);
        canvas.drawCircle(Offset(px, py), kSfDot, fill);
      }
    }

    // Knowledge cluster assembles at top.
    final cluster = ((t - 0.55) / 0.3).clamp(0.0, 1.0);
    if (cluster > 0) {
      final cc = Offset(c.dx, c.dy - size.height * 0.28);
      final nodes = [
        Offset(-0.10, -0.14),
        Offset(0.12, -0.10),
        Offset(0.02, 0.06),
        Offset(-0.13, 0.04),
        Offset(0.16, 0.02),
      ];
      for (var i = 0; i < nodes.length; i++) {
        final n = cc + nodes[i] * size.width * 0.9 * SFPhase.on(cluster, i, 5);
        final on = SFPhase.on(cluster, i, 5);
        fill.color = p.line.withValues(alpha: 0.25 + 0.75 * on);
        canvas.drawCircle(n, kSfDot * 1.6, fill);
        // Connect to center node.
        if (on > 0) {
          canvas.drawLine(
            n,
            cc,
            stroke..color = p.faint.withValues(alpha: on * 0.6),
          );
        }
      }
      fill.color = p.strong;
      canvas.drawCircle(cc, kSfDot * 2.2, fill);
    }

    // Thin checkmark draws itself.
    final check = ((t - 0.86) / 0.14).clamp(0.0, 1.0);
    if (check > 0 && check < 1) {
      final path = Path()
        ..moveTo(c.dx - size.width * 0.08, c.dy - size.height * 0.02)
        ..lineTo(c.dx - size.width * 0.01, c.dy + size.height * 0.05)
        ..lineTo(c.dx + size.width * 0.10, c.dy - size.height * 0.06);
      final metrics = path.computeMetrics().first;
      canvas.drawPath(
        metrics.extractPath(
          0,
          metrics.length * Curves.easeOut.transform(check),
        ),
        stroke..color = p.strong,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UploadPainter old) => old.t != t;
}
