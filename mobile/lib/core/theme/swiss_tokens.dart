// ─────────────────────────────────────────────────────────────────────
// SWISS INTERNATIONAL DESIGN TOKENS — StudyFlow AI
//
// The International Typographic Style: objectivity, precision, grid,
// typography, negative space, clarity, function, structure.
//
// COLORS: Black, White, Swiss Red (#FF3000) only.
// TYPOGRAPHY: Inter — massive, tight, left-aligned.
// SHAPE: Rectangular. No rounded corners.
// SHADOWS: None. Depth from borders and contrast.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// ── COLOR SYSTEM ─────────────────────────────────────────────────────
/// Strict palette: White, Black, Muted, Swiss Red. Nothing else.
abstract final class SwissColors {
  // ── Core ────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color muted = Color(0xFFF2F2F2);
  static const Color red = Color(0xFFFF3000);

  // ── Semantic (light mode) ───────────────────────────────────────
  static const Color background = white;
  static const Color foreground = black;
  static const Color surface = white;
  static const Color onSurface = black;
  static const Color border = black;
  static const Color accent = red;

  // ── Dark mode ───────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkForeground = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF161616);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkMuted = Color(0xFF1A1A1A);
}

/// ── TYPOGRAPHY ───────────────────────────────────────────────────────
/// Inter — grotesque sans-serif. Heavy use of Black (900) and Bold (700).
/// UPPERCASE for headings and labels. Flush left.
abstract final class SwissTypography {
  // ── Display (hero — massive) ────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize: 56,
    height: 0.95,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
  );

  // ── Headline (large section) ────────────────────────────────────
  static const TextStyle headline = TextStyle(
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
  );

  // ── Section (medium heading) ────────────────────────────────────
  static const TextStyle section = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
  );

  // ── Subheading ──────────────────────────────────────────────────
  static const TextStyle subheading = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  // ── Body ────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // ── Body medium (bold body) ─────────────────────────────────────
  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  // ── Label (uppercase, tracked) ──────────────────────────────────
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  // ── Caption ─────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  // ── Mono metadata ───────────────────────────────────────────────
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    letterSpacing: 0.2,
  );
}

/// ── SHAPE TOKENS ─────────────────────────────────────────────────────
/// Strictly rectangular. No rounded corners.
abstract final class SwissShapes {
  /// No radius — rectangular.
  static const double square = 0;

  /// Border widths.
  static const double borderThin = 2;
  static const double borderMedium = 4;
  static const double borderThick = 6;
}

/// ── SPACING ──────────────────────────────────────────────────────────
/// Consistent 4px grid rhythm.
abstract final class SwissSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
  static const double giant = 96;
}

/// ── MOTION ───────────────────────────────────────────────────────────
/// Fast, mechanical, precise. No elastic or bouncy.
abstract final class SwissMotion {
  /// Fast feedback — presses, toggles.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions — navigation, expansion.
  static const Duration medium = Duration(milliseconds: 250);

  /// Long transitions — sheets.
  static const Duration slow = Duration(milliseconds: 400);

  /// Curves — mechanical, precise.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOut;
  static const Curve press = Curves.easeOut;
}

/// ── SECTION NUMBERS ──────────────────────────────────────────────────
/// Swiss editorial section numbering.
abstract final class SwissSections {
  static const String home = '01';
  static const String notebooks = '02';
  static const String ai = '03';
  static const String audio = '04';
  static const String profile = '05';
  static const String settings = '06';
  static const String premium = '07';
}
