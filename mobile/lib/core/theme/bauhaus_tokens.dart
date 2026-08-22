// ─────────────────────────────────────────────────────────────────────
// BAUHAUS DESIGN TOKENS — StudyFlow AI
//
// A constructivist visual language: circles, squares, triangles,
// thick borders, hard shadows, massive typography, and primary colors.
//
// INSPIRED BY: Bauhaus poster design + constructivist art
// INTERPRETED AS: Modern mobile AI learning product
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// Primary color palette — the Bauhaus identity.
abstract final class BauhausColors {
  // ── Core palette ──────────────────────────────────────────────
  static const Color background = Color(0xFFF0F0F0);
  static const Color black = Color(0xFF121212);
  static const Color red = Color(0xFFD02020);
  static const Color blue = Color(0xFF1040C0);
  static const Color yellow = Color(0xFFF0C020);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFE0E0E0);

  // ── Semantic aliases ──────────────────────────────────────────
  static const Color primary = red;
  static const Color secondary = blue;
  static const Color accent = yellow;
  static const Color surface = white;
  static const Color onSurface = black;
  static const Color onPrimary = white;
  static const Color onSecondary = white;
  static const Color onAccent = black;

  // ── Status colors (using Bauhaus palette) ─────────────────────
  static const Color success = black; // CHECKMARK in black
  static const Color error = red;
  static const Color warning = yellow;
  static const Color info = blue;
}

/// Typography scale — massive, bold, geometric.
/// Uses the system geometric sans-serif (closest to Outfit).
abstract final class BauhausTypography {
  // ── Display (hero) ────────────────────────────────────────────
  static const TextStyle hero = TextStyle(
    fontSize: 56,
    height: 0.95,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    color: BauhausColors.black,
  );

  static const TextStyle heroWhite = TextStyle(
    fontSize: 56,
    height: 0.95,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    color: BauhausColors.white,
  );

  // ── Headline ──────────────────────────────────────────────────
  static const TextStyle headline = TextStyle(
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: BauhausColors.black,
  );

  static const TextStyle headlineWhite = TextStyle(
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: BauhausColors.white,
  );

  // ── Section heading ───────────────────────────────────────────
  static const TextStyle section = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    color: BauhausColors.black,
  );

  static const TextStyle sectionWhite = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    color: BauhausColors.white,
  );

  // ── Subheading ────────────────────────────────────────────────
  static const TextStyle subheading = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: BauhausColors.black,
  );

  // ── Body ──────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: BauhausColors.black,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: BauhausColors.black,
  );

  // ── Label (uppercase, tracked) ────────────────────────────────
  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: BauhausColors.black,
  );

  static const TextStyle labelWhite = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: BauhausColors.white,
  );

  static const TextStyle labelMuted = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: BauhausColors.black,
  );

  // ── Caption ───────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: BauhausColors.black,
  );
}

/// Shape tokens — only TWO radius styles.
abstract final class BauhausShapes {
  /// Square — no radius.
  static const double square = 0;

  /// Circle — fully rounded.
  static const double circle = 9999;

  /// Border widths.
  static const double borderThin = 2;
  static const double borderMedium = 4;
  static const double borderThick = 6;
}

/// Hard shadow system — physical, graphic, no blur.
abstract final class BauhausShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: BauhausColors.black,
      offset: Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: BauhausColors.black,
      offset: Offset(6, 6),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> large = [
    BoxShadow(
      color: BauhausColors.black,
      offset: Offset(8, 8),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> none = [];
}

/// Spacing scale — consistent rhythm.
abstract final class BauhausSpacing {
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
}

/// Motion tokens — mechanical, snappy, geometric.
abstract final class BauhausMotion {
  /// Fast feedback — presses, toggles.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions — navigation, expansion.
  static const Duration medium = Duration(milliseconds: 250);

  /// Long transitions — sheets, hero morphs.
  static const Duration slow = Duration(milliseconds: 400);

  /// Press physics.
  static const Duration pressIn = Duration(milliseconds: 80);
  static const Duration pressOut = Duration(milliseconds: 320);

  /// Curves.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutBack;
  static const Curve press = Curves.easeOut;
}
