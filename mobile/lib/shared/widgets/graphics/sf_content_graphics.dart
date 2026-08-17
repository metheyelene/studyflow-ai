/// Content-generation graphics: knowledge becoming artifacts.
///
/// Flashcards stack into a deck, quiz questions frame up, a study guide
/// forms its hierarchy, notes organize into structure, and podcast notes
/// become a waveform. Each tells the story of material being understood.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sf_graphic_base.dart';

/// Flashcards: cards appear one by one, each with brief text lines, and
/// stack into a deck — then the deck compresses into a bright spine.
class SFFlashcardStackGraphic extends StatelessWidget {
  const SFFlashcardStackGraphic({
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
      paint: (t, p) => _FlashcardPainter(t, p),
    );
  }
}

class _FlashcardPainter extends CustomPainter {
  _FlashcardPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    const n = 4;
    final cardW = size.width * 0.44;
    final cardH = size.height * 0.3;
    final left = c.dx - cardW / 2;

    for (var i = 0; i < n; i++) {
      final appear = SFPhase.on(t, i, n, spread: 0.6);
      if (appear <= 0) continue;
      final y =
          c.dy -
          cardH / 2 +
          i * cardH * 0.14 * Curves.easeOut.transform(appear);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * 4, y, cardW, cardH),
        const Radius.circular(6),
      );
      // Card body — dark glass fill for the front card.
      final isTop = i == n - 1;
      stroke.color = isTop ? p.line : p.faint.withValues(alpha: 0.6);
      canvas.drawRRect(rect, stroke);
      if (isTop) {
        // Text lines briefly appear on the top card.
        final linePaint = Paint()
          ..color = p.line.withValues(alpha: 0.7)
          ..strokeWidth = kSfLineWeight
          ..strokeCap = StrokeCap.round;
        for (var li = 0; li < 3; li++) {
          canvas.drawLine(
            Offset(left + cardW * 0.16, y + cardH * (0.3 + li * 0.18)),
            Offset(
              left + cardW * (li == 2 ? 0.6 : 0.84),
              y + cardH * (0.3 + li * 0.18),
            ),
            linePaint,
          );
        }
      }
    }

    // Deck compresses into a bright spine near the end of the loop.
    final compress = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
    if (compress > 0) {
      final spineH = cardH * (1 - 0.75 * compress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + n * 4, c.dy - spineH / 2, 6, spineH),
          const Radius.circular(3),
        ),
        stroke..color = p.strong,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlashcardPainter old) => old.t != t;
}

/// Quiz: a question outline appears, answer lines below, several frames
/// stack, then settle into a compact "quiz" mark.
class SFQuizFramesGraphic extends StatelessWidget {
  const SFQuizFramesGraphic({
    super.key,
    this.size = const Size(96, 88),
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
      paint: (t, p) => _QuizPainter(t, p),
    );
  }
}

class _QuizPainter extends CustomPainter {
  _QuizPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    final c = Offset(size.width / 2, size.height / 2);
    final frameW = size.width * 0.5;
    final frameH = size.height * 0.4;

    for (var i = 0; i < 3; i++) {
      final appear = SFPhase.on(t, i, 3, spread: 0.55);
      if (appear <= 0) continue;
      final y =
          c.dy -
          frameH / 2 +
          i * frameH * 0.18 * Curves.easeOut.transform(appear);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - frameW / 2 + i * 4, y, frameW, frameH),
        const Radius.circular(5),
      );
      final isTop = i == 2;
      stroke.color = isTop ? p.line : p.faint.withValues(alpha: 0.55);
      canvas.drawRRect(rect, stroke);

      // Question mark + answer lines on the top frame.
      if (isTop) {
        canvas.drawCircle(
          Offset(c.dx - frameW * 0.3, y + frameH * 0.3),
          kSfDot * 1.8,
          fill..color = p.line.withValues(alpha: 0.8),
        );
        final linePaint = Paint()
          ..color = p.line.withValues(alpha: 0.7)
          ..strokeWidth = kSfLineWeight
          ..strokeCap = StrokeCap.round;
        for (var li = 0; li < 3; li++) {
          canvas.drawLine(
            Offset(c.dx - frameW * 0.12, y + frameH * (0.2 + li * 0.2)),
            Offset(
              c.dx - frameW * 0.12 + frameW * (li == 1 ? 0.6 : 0.42),
              y + frameH * (0.2 + li * 0.2),
            ),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QuizPainter old) => old.t != t;
}

/// Study guide: sections progressively appear and align into a
/// hierarchy — title, concepts, key points, review.
class SFStudyGuideGraphic extends StatelessWidget {
  const SFStudyGuideGraphic({
    super.key,
    this.size = const Size(88, 96),
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
      paint: (t, p) => _GuidePainter(t, p),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    final left = size.width * 0.2;

    // Hierarchy: title (bold wide), then indented sections.
    final rows = [
      (0.12, 0.9, 0.0, true), // title
      (0.34, 0.62, 0.12, false), // concepts
      (0.50, 0.62, 0.12, false), // key points
      (0.66, 0.5, 0.12, false), // review
      (0.80, 0.45, 0.12, false),
    ];
    for (var i = 0; i < rows.length; i++) {
      final (yFrac, len, indent, isTitle) = rows[i];
      final appear = SFPhase.on(t, i, rows.length, spread: 0.6);
      if (appear <= 0) continue;
      final y = size.height * yFrac;
      final x = left + size.width * indent;
      final w = size.width * len;
      if (isTitle) {
        // Title is a short bold bar.
        stroke.strokeWidth = kSfLineWeight * 2;
      }
      canvas.drawLine(
        Offset(x, y),
        Offset(x + w * Curves.easeOut.transform(appear), y),
        stroke..color = p.line.withValues(alpha: 0.4 + 0.6 * appear),
      );
      stroke.strokeWidth = kSfLineWeight;
    }

    // A small "review" dot completes the guide.
    final done = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
    if (done > 0) {
      fill.color = p.strong.withValues(alpha: done);
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.92),
        kSfDot * 1.8,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => old.t != t;
}

/// Podcast: notes → script → voice. Document lines give way to a
/// waveform that animates.
class SFPodcastGraphic extends StatelessWidget {
  const SFPodcastGraphic({
    super.key,
    this.size = const Size(120, 64),
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
      paint: (t, p) => _PodcastPainter(t, p),
    );
  }
}

class _PodcastPainter extends CustomPainter {
  _PodcastPainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Phase 1 (0–0.4): document lines.
    final doc = ((t - 0) / 0.4).clamp(0.0, 1.0);
    if (doc > 0 && doc < 1) {
      for (var i = 0; i < 4; i++) {
        final y = size.height * (0.2 + i * 0.2);
        final w = size.width * (i == 3 ? 0.3 : 0.5 - i * 0.04);
        canvas.drawLine(
          Offset(size.width * 0.1, y),
          Offset(size.width * 0.1 + w * Curves.easeOut.transform(doc), y),
          stroke..color = p.faint.withValues(alpha: 0.8),
        );
      }
    }

    // Phase 2 (0.4–1): waveform emerges and animates.
    final wave = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
    if (wave > 0) {
      const bars = 16;
      final gap = size.width / (bars + 1);
      for (var i = 0; i < bars; i++) {
        final x = gap * (i + 1);
        final on = SFPhase.on(wave, i, bars, spread: 0.5);
        if (on <= 0) continue;
        final mid = 1 - (i - bars / 2).abs() / (bars / 2);
        final amp =
            0.15 +
            0.3 * mid * (0.6 + 0.4 * math.sin(t * 2 * math.pi * 1.5 + i * 1.1));
        final half = size.height * 0.42 * amp * Curves.easeOut.transform(on);
        canvas.drawLine(
          Offset(x, size.height / 2 - half),
          Offset(x, size.height / 2 + half),
          stroke..color = p.line.withValues(alpha: 0.3 + 0.7 * on),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PodcastPainter old) => old.t != t;
}

/// Note organization: random lines group into aligned sections — messy
/// notes become structured knowledge.
class SFNoteOrganizeGraphic extends StatelessWidget {
  const SFNoteOrganizeGraphic({
    super.key,
    this.size = const Size(96, 88),
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
      paint: (t, p) => _OrganizePainter(t, p),
    );
  }
}

class _OrganizePainter extends CustomPainter {
  _OrganizePainter(this.t, this.p);

  final double t;
  final SFGraphicPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = p.line
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;

    // Messy phase (0–0.45): ragged lines at random offsets.
    final organize = SFPhase.inOut((t / 0.45).clamp(0, 1));
    const n = 6;
    for (var i = 0; i < n; i++) {
      final y = size.height * (0.14 + i * 0.14);
      final ragged = 1 - organize;
      final left =
          size.width * 0.12 + size.width * 0.1 * math.sin(i * 2.7) * ragged;
      final w =
          size.width * (0.34 + 0.1 * math.sin(i * 1.9)) * (1 - 0.2 * ragged) +
          size.width * 0.2 * organize;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + w, y),
        stroke..color = p.faint.withValues(alpha: 0.35 + 0.6 * organize),
      );
    }

    // Organized phase (0.45–1): section headings emerge (bold bars).
    final sections = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    if (sections > 0) {
      for (var i = 0; i < 2; i++) {
        final y = size.height * (0.24 + i * 0.48);
        final on = SFPhase.on(sections, i, 2);
        if (on <= 0) continue;
        canvas.drawLine(
          Offset(size.width * 0.12, y),
          Offset(size.width * 0.12 + size.width * 0.2 * on, y),
          stroke
            ..strokeWidth = kSfLineWeight * 2
            ..color = p.strong.withValues(alpha: on),
        );
        stroke.strokeWidth = kSfLineWeight;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrganizePainter old) => old.t != t;
}

/// Onboarding: a five-beat visual story — DOCUMENT → DOCUMENTS CONNECT →
/// AI ANALYZES → KNOWLEDGE ORGANIZES → YOU STUDY. Each step is a small
/// static composition of the same language, with one beat breathing.
enum SFOnboardingStep {
  document,
  documentsConnect,
  aiAnalyzes,
  knowledgeOrganizes,
  youStudy,
}

class SFOnboardingGraphic extends StatelessWidget {
  const SFOnboardingGraphic({
    super.key,
    required this.step,
    this.size = const Size(140, 140),
    this.paused = false,
  });

  final SFOnboardingStep step;
  final Size size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SFGraphic(
      size: size,
      paused: paused,
      loopDuration: AppMotion.graphicsLoop,
      paint: (t, p) => _OnboardingPainter(t, p, step),
    );
  }
}

class _OnboardingPainter extends CustomPainter {
  _OnboardingPainter(this.t, this.p, this.step);

  final double t;
  final SFGraphicPalette p;
  final SFOnboardingStep step;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSfLineWeight
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final breathe = 0.5 + 0.5 * SFPhase.pulse(t);

    switch (step) {
      case SFOnboardingStep.document:
        // A single document silhouette.
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c,
            width: size.width * 0.34,
            height: size.height * 0.5,
          ),
          const Radius.circular(6),
        );
        stroke.color = p.line.withValues(alpha: 0.7 + 0.3 * breathe);
        canvas.drawRRect(rect, stroke);
        SFLines.textLines(
          canvas,
          Offset(rect.left + size.width * 0.06, rect.top + size.height * 0.2),
          rect.width,
          4,
          size.height * 0.07,
          stroke..color = p.faint,
        );

      case SFOnboardingStep.documentsConnect:
        // Two documents linked by a line.
        for (var i = 0; i < 2; i++) {
          final dx = c.dx + (i == 0 ? -size.width * 0.2 : size.width * 0.2);
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(dx, c.dy),
              width: size.width * 0.22,
              height: size.height * 0.4,
            ),
            const Radius.circular(5),
          );
          stroke.color = p.line.withValues(alpha: 0.7);
          canvas.drawRRect(rect, stroke);
        }
        final mid = 0.5 + 0.5 * SFPhase.pulse(t);
        canvas.drawLine(
          Offset(c.dx - size.width * 0.09, c.dy),
          Offset(c.dx + size.width * 0.09, c.dy),
          stroke..color = p.strong.withValues(alpha: 0.4 + 0.6 * mid),
        );

      case SFOnboardingStep.aiAnalyzes:
        // A document feeding a thinking mark.
        final doc = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            c.dx - size.width * 0.26,
            c.dy + size.height * 0.06,
            size.width * 0.3,
            size.height * 0.3,
          ),
          const Radius.circular(5),
        );
        stroke.color = p.faint.withValues(alpha: 0.8);
        canvas.drawRRect(doc, stroke);
        // Thinking mark above.
        final r = size.width * 0.14;
        stroke.color = p.line;
        canvas.drawCircle(
          Offset(c.dx + size.width * 0.12, c.dy - size.height * 0.18),
          r,
          stroke,
        );
        final a = t * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(c.dx + size.width * 0.12, c.dy - size.height * 0.18),
            radius: r * 0.6,
          ),
          a,
          1.6,
          false,
          stroke..color = p.strong,
        );
        // Upward particles.
        for (var i = 0; i < 3; i++) {
          final pr = ((t + i / 3) % 1.0);
          final py = c.dy + size.height * 0.06 - pr * size.height * 0.3;
          fill.color = p.faint.withValues(alpha: 1 - pr);
          canvas.drawCircle(
            Offset(c.dx - size.width * 0.11 + i * size.width * 0.03, py),
            kSfDot,
            fill,
          );
        }

      case SFOnboardingStep.knowledgeOrganizes:
        // A small knowledge cluster assembling.
        const pts = [
          Offset(-0.18, -0.2),
          Offset(0.18, -0.16),
          Offset(0.0, 0.04),
          Offset(-0.2, 0.16),
          Offset(0.2, 0.2),
        ];
        for (var i = 0; i < pts.length; i++) {
          final n = c + pts[i] * size.width;
          final on = 0.5 + 0.5 * SFPhase.pulse(t + i * 0.3);
          canvas.drawLine(
            c,
            n,
            stroke..color = p.faint.withValues(alpha: 0.35 + 0.4 * on),
          );
          fill.color = p.line.withValues(alpha: 0.4 + 0.6 * on);
          canvas.drawCircle(n, kSfDot * 1.8, fill);
        }
        fill.color = p.strong;
        canvas.drawCircle(c, kSfDot * 2.4, fill);

      case SFOnboardingStep.youStudy:
        // A document with a bright checkmark — ready to study.
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c,
            width: size.width * 0.34,
            height: size.height * 0.46,
          ),
          const Radius.circular(6),
        );
        stroke.color = p.line.withValues(alpha: 0.75);
        canvas.drawRRect(rect, stroke);
        final check = Path()
          ..moveTo(c.dx - size.width * 0.09, c.dy)
          ..lineTo(c.dx - size.width * 0.01, c.dy + size.height * 0.07)
          ..lineTo(c.dx + size.width * 0.11, c.dy - size.height * 0.06);
        final m = check.computeMetrics().first;
        final drawn = (0.5 + 0.5 * SFPhase.pulse(t)).clamp(0.2, 1.0);
        canvas.drawPath(
          m.extractPath(0, m.length * drawn),
          stroke..color = p.strong,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingPainter old) =>
      old.t != t || old.step != step;
}
