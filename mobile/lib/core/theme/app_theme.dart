import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../performance/device_tier.dart';

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

/// Motion tokens — the single source for animation curves and durations
/// (Material 3 Expressive motion language). Components animate with these
/// instead of ad-hoc `Duration(milliseconds: …)` values.
abstract final class AppMotion {
  /// Standard in-out motion for state changes and reordering.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasized motion for large surfaces appearing (sheets, dialogs).
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Spring-like entrance for objects scaling into place (cards, FABs).
  static const Curve entrance = Curves.easeOutBack;

  /// Fast feedback — presses, toggles, micro-interactions.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions — navigation, expansion, appearance.
  static const Duration medium = Duration(milliseconds: 250);

  /// Long, expressive transitions — sheets, hero-style morphs.
  static const Duration slow = Duration(milliseconds: 400);

  /// Press physics: compress quickly with a sharp ease-out…
  static const Curve pressIn = Curves.easeOut;
  static const Duration pressInDuration = Duration(milliseconds: 80);

  /// …then spring back with a physical overshoot. Physical controls
  /// (buttons, cards, chips) release through these tokens.
  static const Curve pressOut = Curves.easeOutBack;
  static const Duration pressOutDuration = Duration(milliseconds: 320);

  /// Subtle idle drift for ambient background light (very slow, GPU-cheap
  /// opacity/position tween — never a per-frame transform on content).
  static const Duration ambient = Duration(seconds: 12);
}

/// Shape tokens — the single source for corner radii. Shape communicates
/// hierarchy: small radii for dense inputs, larger radii for surfaces that
/// float above content, pills for actions.
abstract final class AppShapes {
  /// Inputs, chips' inner details, small affordances.
  static const double input = 12;

  /// Buttons.
  static const double button = 14;

  /// Standard cards and list tiles.
  static const double card = 20;

  /// Dialogs and modals.
  static const double dialog = 24;

  /// Bottom sheets and the navigation bar indicator.
  static const double sheet = 28;

  /// Hero surfaces — featured cards, the player, the paywall.
  static const double hero = 28;

  /// Fully rounded pills.
  static const double pill = 999;
}

/// StudyFlow typography scale — the one place font sizes/weights/letter-spacing
/// are defined. Screens should reference these instead of inline `fontSize:`.
abstract final class AppText {
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle captionMuted = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle eyebrow = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  static const TextStyle small = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle smallMuted = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
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
    required this.secondary,
    required this.ai,
    required this.audio,
    required this.textPrimary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.amber,
    required this.blurRadius,
    required this.blurEnabled,
    required this.reducedEffects,
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

  /// Light gray — secondary actions and links.
  final Color secondary;

  /// Near-white — the AI signal color (orbs, thinking states, AI accents).
  final Color ai;

  /// Bright gray — the audio/podcast accent.
  final Color audio;

  final Color textPrimary;
  final Color textMuted;
  final Color textOnPrimary;
  final Color danger;
  final Color success;
  final Color warning;
  final Color amber;
  final double blurRadius;
  final bool blurEnabled;

  /// True on the low rendering tier: ambient/hero gradients and heavy drop
  /// shadows are disabled app-wide (blur radius is handled separately via
  /// [blurRadius]). Components read this through `context.glass` so no
  /// provider plumbing is needed — the theme already carries the tier.
  final bool reducedEffects;

  static const radiusCard = 24.0;
  static const radiusInner = 16.0;
  static const radiusPill = 999.0;

  static const light = GlassTheme(
    background: Color(0xFFF5F5F5),
    // Light glass mirrors dark's luminance physics: surfaces are the base
    // family catching light, translucent enough for the ambient mood to
    // bleed through (85% cards, 92% shell) so they read as glass over the
    // environment, not flat white panels. Depth ordering matches dark —
    // floating ≈ surfaceStrong (closest to the user = strongest fill).
    surface: Color(0xE0FFFFFF),
    surfaceStrong: Color(0xF0FFFFFF),
    surfaceSubtle: Color(0xB3FFFFFF),
    floating: Color(0xECFFFFFF),
    // Light glass is monochrome too: the edge is a soft neutral gray
    // (black at low alpha) and the top-lip highlight a white catch-light.
    // On near-white fills the white lip is faint, so the gray edge does
    // the material work — the surface reads as glass over the ambient
    // gray fields instead of a flat white panel.
    border: Color(0x26000000),
    highlight: Color(0x59FFFFFF),
    // Light-mode tokens are tuned for WCAG 4.5:1 on the painted surfaces:
    // BLACK is the accent (primary/links, ~19:1 on white) so white
    // button labels and black links both clear AA comfortably. Purpose
    // accents (secondary, AI, audio) are darker grays; status colors are
    // grays at AA on every painted surface, separated by brightness and
    // iconography — never hue.
    primary: Color(0xFF000000),
    primarySoft: Color(0x12000000),
    secondary: Color(0xFF333333),
    ai: Color(0xFF111111),
    audio: Color(0xFF262626),
    textPrimary: Color(0xFF111111),
    textMuted: Color(0xFF555555),
    textOnPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFF6B6B6B),
    success: Color(0xFF000000),
    warning: Color(0xFF3D3D3D),
    amber: Color(0xFF3D3D3D),
    blurRadius: 24,
    blurEnabled: true,
    reducedEffects: false,
  );

  // Dark mode is a MONOCHROME OBSIDIAN environment: near-black neutral
  // surfaces dominate (~80% of the screen), and WHITE is the accent —
  // reserved for controls, progress, AI states, and contextual
  // indicators, never for painting whole surfaces. The glass edge and
  // top-lip highlight are a subtle neutral light (≈6-8% white): a
  // low-alpha catch-light reads as glass catching light, not fog. Every
  // purpose accent (primary, AI, audio, success) is a shade of white;
  // status separation comes from brightness + iconography, never hue.
  static const dark = GlassTheme(
    background: Color(0xFF0A0A0A),
    surface: Color(0xC21B1B1B),
    surfaceStrong: Color(0xE8242424),
    surfaceSubtle: Color(0x7F282828),
    floating: Color(0xE62C2C2C),
    border: Color(0x12FFFFFF),
    highlight: Color(0x0FFFFFFF),
    primary: Color(0xFFFFFFFF),
    primarySoft: Color(0x14FFFFFF),
    secondary: Color(0xFFCCCCCC),
    ai: Color(0xFFF5F5F5),
    audio: Color(0xFFE6E6E6),
    textPrimary: Color(0xFFF5F5F5),
    textMuted: Color(0xFF9E9E9E),
    textOnPrimary: Color(0xFF000000),
    danger: Color(0xFFA3A3A3),
    success: Color(0xFFFFFFFF),
    warning: Color(0xFFCBCBCB),
    amber: Color(0xFFCBCBCB),
    blurRadius: 36,
    blurEnabled: true,
    reducedEffects: false,
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
    Color? secondary,
    Color? ai,
    Color? audio,
    Color? textPrimary,
    Color? textMuted,
    Color? textOnPrimary,
    Color? danger,
    Color? success,
    Color? warning,
    Color? amber,
    double? blurRadius,
    bool? blurEnabled,
    bool? reducedEffects,
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
      secondary: secondary ?? this.secondary,
      ai: ai ?? this.ai,
      audio: audio ?? this.audio,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      amber: amber ?? this.amber,
      blurRadius: blurRadius ?? this.blurRadius,
      blurEnabled: blurEnabled ?? this.blurEnabled,
      reducedEffects: reducedEffects ?? this.reducedEffects,
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
      secondary: Color.lerp(secondary, other.secondary, t)!,
      ai: Color.lerp(ai, other.ai, t)!,
      audio: Color.lerp(audio, other.audio, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      blurRadius: t < 0.5 ? blurRadius : other.blurRadius,
      blurEnabled: t < 0.5 ? blurEnabled : other.blurEnabled,
      reducedEffects: t < 0.5 ? reducedEffects : other.reducedEffects,
    );
  }
}

/// Convenience accessor: `context.glass`.
extension GlassBuildContext on BuildContext {
  GlassTheme get glass => Theme.of(this).extension<GlassTheme>()!;
}

/// StudyFlow brand palette — a MONOCHROME identity: black, white, and
/// neutral grays only. WHITE is the accent in dark mode, BLACK in light
/// mode; purpose accents (AI, audio, success) are shades of white/gray,
/// and separation comes from brightness + iconography, never hue. The
/// neutral seed keeps the scheme gray even when the platform supplies
/// dynamic color.
abstract final class AppColors {
  /// Neutral seed (near-black) — dark-mode primary is white, light-mode
  /// primary is black.
  static const teal = Color(0xFF000000);
  static const tealLight = Color(0xFFFFFFFF);
  static const cyan = Color(0xFFF5F5F5);
  static const coral = Color(0xFFE6E6E6);
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFFCFCFC);
}

/// Build the full Material 3 Expressive [ColorScheme]: a neutral seeded
/// palette as the fallback, optionally harmonized with the platform's
/// dynamic color scheme (Android 12+) for the neutral/system roles.
/// StudyFlow is strictly monochrome — white is the dark-mode primary,
/// black the light-mode primary — and the neutral seed keeps the system
/// gray even when dynamic color is supplied.
ColorScheme _buildScheme(Brightness brightness, ColorScheme? dynamicScheme) {
  final isDark = brightness == Brightness.dark;
  final seed = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
  );
  return (dynamicScheme ?? seed).copyWith(
    // Dark primary is white (the accent); light primary is black.
    primary: isDark ? AppColors.tealLight : AppColors.teal,
    onPrimary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    primaryContainer: isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFE6E6E6),
    onPrimaryContainer: isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111),
    secondary: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
    onSecondary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    secondaryContainer: isDark
        ? const Color(0xFF292929)
        : const Color(0xFFD9D9D9),
    onSecondaryContainer: isDark
        ? const Color(0xFFE6E6E6)
        : const Color(0xFF222222),
    tertiary: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF4A4A4A),
    onTertiary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    tertiaryContainer: isDark
        ? const Color(0xFF262626)
        : const Color(0xFFE0E0E0),
    onTertiaryContainer: isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF262626),
    inversePrimary: isDark ? AppColors.teal : AppColors.tealLight,
    surfaceTint: isDark ? AppColors.tealLight : AppColors.teal,
    surface: isDark ? const Color(0xFF131313) : const Color(0xFFFAFAFA),
    // Both modes get an explicit neutral container ramp so system
    // components (dialogs, chips, popups, input fills, progress tracks)
    // share the same environment as the custom surfaces: dark steps the
    // obsidian family (near-black, neutral), light steps the paper family
    // (near-white, neutral) — no hue in either mode.
    surfaceContainerLowest: isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: isDark
        ? const Color(0xFF0D0D0D)
        : const Color(0xFFF4F4F4),
    surfaceContainer: isDark
        ? const Color(0xFF131313)
        : const Color(0xFFECECEC),
    surfaceContainerHigh: isDark
        ? const Color(0xFF171717)
        : const Color(0xFFE5E5E5),
    surfaceContainerHighest: isDark
        ? const Color(0xFF1D1D1D)
        : const Color(0xFFDEDEDE),
    onSurface: isDark ? const Color(0xFFF2F2F2) : AppColors.ink,
    onSurfaceVariant: isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF555555),
    outlineVariant: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFCCCCCC),
    error: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF4D4D4D),
    onError: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    errorContainer: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE1E1E1),
    onErrorContainer: isDark
        ? const Color(0xFFE1E1E1)
        : const Color(0xFF2A2A2A),
  );
}

/// Complete Material 3 type scale with StudyFlow's expressive weights.
TextTheme _buildTextTheme(ColorScheme scheme) {
  final display = scheme.onSurface;
  final muted = scheme.onSurfaceVariant;
  TextStyle t(
    double size,
    double height,
    FontWeight weight,
    double spacing,
    Color color,
  ) => TextStyle(
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );

  return TextTheme(
    displayLarge: t(57, 1.12, FontWeight.w700, -0.25, display),
    displayMedium: t(45, 1.16, FontWeight.w700, -0.2, display),
    displaySmall: t(36, 1.22, FontWeight.w700, -0.1, display),
    headlineLarge: t(32, 1.25, FontWeight.w600, -0.1, display),
    headlineMedium: t(28, 1.29, FontWeight.w600, 0, display),
    headlineSmall: t(24, 1.33, FontWeight.w600, 0, display),
    titleLarge: t(22, 1.27, FontWeight.w600, 0, display),
    titleMedium: t(16, 1.5, FontWeight.w600, 0.15, display),
    titleSmall: t(14, 1.43, FontWeight.w600, 0.1, display),
    bodyLarge: t(16, 1.5, FontWeight.w400, 0.5, display),
    bodyMedium: t(14, 1.43, FontWeight.w400, 0.25, muted),
    bodySmall: t(12, 1.33, FontWeight.w400, 0.4, muted),
    labelLarge: t(14, 1.43, FontWeight.w600, 0.1, scheme.primary),
    labelMedium: t(12, 1.33, FontWeight.w600, 0.5, muted),
    labelSmall: t(11, 1.45, FontWeight.w600, 0.5, muted),
  );
}

/// Build the StudyFlow theme: Material 3 Expressive design tokens, component
/// themes for every M3 widget the app uses, and the glass extension.
///
/// [dynamicScheme] is the platform dynamic color scheme (Android 12+ via
/// `DynamicColorBuilder`); when null the branded seed palette is used.
/// [tier] is the rendering-performance tier: on low-tier devices the glass
/// blur radius drops (24→10 light, 36→14 dark) so the most GPU-expensive
/// effect stays cheap; blur is never fully disabled because a small sigma
/// keeps the material language intact for a fraction of the cost.
ThemeData buildAppTheme(
  Brightness brightness, {
  ColorScheme? dynamicScheme,
  PerformanceTier tier = PerformanceTier.standard,
}) {
  final isDark = brightness == Brightness.dark;
  final scheme = _buildScheme(brightness, dynamicScheme);
  final text = _buildTextTheme(scheme);
  final glass = isDark ? GlassTheme.dark : GlassTheme.light;

  WidgetStateProperty<Color?> stateColor(Color selected, Color unselected) {
    return WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? selected : unselected,
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    // M3 Expressive motion: ripple + page transitions carry the easing;
    // InkSparkle gives the M3 sparkle ink response on press.
    splashFactory: InkSparkle.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: scheme.primary.withValues(alpha: 0.06),
    focusColor: scheme.primary.withValues(alpha: 0.12),
    textTheme: text,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.sheet),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      labelType: NavigationRailLabelType.all,
    ),
    cardTheme: CardThemeData(
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.dialog),
      ),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.sheet),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.button),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.button),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.button),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.input),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: stateColor(scheme.onPrimary, scheme.onSurfaceVariant),
      trackColor: stateColor(scheme.primary, scheme.surfaceContainerHighest),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primaryContainer,
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.pill),
      ),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: scheme.surfaceContainer,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        foregroundColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.button),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.input),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppShapes.input),
      ),
      textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
      textStyle: text.bodyLarge,
    ),
    extensions: [
      tier == PerformanceTier.low
          ? glass.copyWith(blurRadius: isDark ? 14 : 10, reducedEffects: true)
          : glass,
    ],
  );
}
