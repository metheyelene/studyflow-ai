import 'package:flutter/material.dart';

/// Spacing scale — the single source for layout gaps. New screens use
/// these tokens instead of arbitrary paddings (docs/design-quality-audit.md).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
}

/// Typography scale — the one place font sizes/weights/letter-spacing are
/// defined. Screens should reference these instead of inline `fontSize:`.
abstract final class AppText {
  static const TextStyle caption = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500);
  static const TextStyle captionMuted = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500);
  static const TextStyle body = TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600);
  static const TextStyle eyebrow = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: 0.8);
  static const TextStyle small = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w400);
  static const TextStyle smallMuted = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w400);
}

/// StudyFlow glass design tokens — the single source for the translucent
/// material system (docs/glass-ui-overhaul.md, docs/mobile-flutter-plan.md).
///
/// Four material tiers, like the web design system:
///   surface        → content cards            (most translucent)
///   surfaceStrong  → navigation shell, modals (strongest blur/fill)
///   surfaceSubtle  → widgets, secondary      (most transparent)
///   floating       → quick actions, elevated
///
/// Rule: cards use translucent fill + border WITHOUT per-card blur
/// (BackdropFilter is GPU-expensive). Blur is reserved for the shell,
/// sheets, and modals — see [GlassTheme.blurEnabled].
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.surfaceSubtle,
    required this.floating,
    required this.border,
    required this.highlight,
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.amber,
    required this.blurRadius,
    required this.blurEnabled,
  });

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color surfaceSubtle;
  final Color floating;
  final Color border;
  final Color highlight;
  final Color primary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textMuted;
  final Color textOnPrimary;
  final Color danger;
  final Color success;
  final Color warning;
  final Color amber;
  final double blurRadius;
  final bool blurEnabled;

  static const radiusCard = 24.0;
  static const radiusInner = 16.0;
  static const radiusPill = 999.0;

  static const light = GlassTheme(
    background: Color(0xFFF4F4F8),
    surface: Color(0xE6FFFFFF),
    surfaceStrong: Color(0xF2FFFFFF),
    surfaceSubtle: Color(0xB3FFFFFF),
    floating: Color(0xE0FFFFFF),
    border: Color(0x1A6B7280),
    highlight: Color(0x66FFFFFF),
    primary: Color(0xFF6366F1),
    primarySoft: Color(0x146366F1),
    textPrimary: Color(0xFF17171C),
    textMuted: Color(0xFF6B7280),
    textOnPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    amber: Color(0xFFF59E0B),
    blurRadius: 24,
    blurEnabled: true,
  );

  static const dark = GlassTheme(
    background: Color(0xFF121216),
    surface: Color(0xB31A1A22),
    surfaceStrong: Color(0xE61F1F28),
    surfaceSubtle: Color(0x801F1F28),
    floating: Color(0xCC1F1F28),
    border: Color(0x1AFFFFFF),
    highlight: Color(0x14FFFFFF),
    primary: Color(0xFF818CF8),
    primarySoft: Color(0x1A818CF8),
    textPrimary: Color(0xFFF2F2F5),
    textMuted: Color(0xFF9DA0AA),
    textOnPrimary: Color(0xFF111114),
    danger: Color(0xFFF87171),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    amber: Color(0xFFFBBF24),
    blurRadius: 36,
    blurEnabled: true,
  );

  @override
  GlassTheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceStrong,
    Color? surfaceSubtle,
    Color? floating,
    Color? border,
    Color? highlight,
    Color? primary,
    Color? primarySoft,
    Color? textPrimary,
    Color? textMuted,
    Color? textOnPrimary,
    Color? danger,
    Color? success,
    Color? warning,
    Color? amber,
    double? blurRadius,
    bool? blurEnabled,
  }) {
    return GlassTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      floating: floating ?? this.floating,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      amber: amber ?? this.amber,
      blurRadius: blurRadius ?? this.blurRadius,
      blurEnabled: blurEnabled ?? this.blurEnabled,
    );
  }

  @override
  GlassTheme lerp(GlassTheme other, double t) {
    return GlassTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      floating: Color.lerp(floating, other.floating, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      blurRadius: t < 0.5 ? blurRadius : other.blurRadius,
      blurEnabled: t < 0.5 ? blurEnabled : other.blurEnabled,
    );
  }
}

/// Convenience accessor: `context.glass`.
extension GlassBuildContext on BuildContext {
  GlassTheme get glass => Theme.of(this).extension<GlassTheme>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1),
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
    surface: isDark ? const Color(0xFF1A1A22) : const Color(0xFFFFFFFF),
    error: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF121216) : const Color(0xFFF4F4F8),
  );

  return base.copyWith(
    extensions: [isDark ? GlassTheme.dark : GlassTheme.light],
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF17171C),
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF17171C),
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF17171C),
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF17171C),
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF17171C),
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: isDark ? const Color(0xFF9DA0AA) : const Color(0xFF6B7280),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}
