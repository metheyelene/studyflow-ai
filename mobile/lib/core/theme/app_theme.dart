import 'package:flutter/cupertino.dart';
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
    // Light-mode tokens are tuned for WCAG 4.5:1 on the painted surfaces
    // (see the contrast audit in docs/design-quality-audit.md): the brand
    // indigo sits a touch deeper (#5B5FE0) so white button labels and
    // indigo links both clear AA, and success/warning/muted are darkened
    // accordingly. Dark mode already passes every pair.
    primary: Color(0xFF5B5FE0),
    primarySoft: Color(0x145B5FE0),
    textPrimary: Color(0xFF17171C),
    textMuted: Color(0xFF52525B),
    textOnPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFB91C1C),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    amber: Color(0xFFB45309),
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

/// StudyFlow brand palette. The indigo is the product signature; it stays
/// the primary even when the platform supplies a dynamic color scheme.
abstract final class AppColors {
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const ink = Color(0xFF17171C);
  static const paper = Color(0xFFFCFCFF);
}

/// Build the full Material 3 Expressive [ColorScheme]: a branded seed-based
/// palette as the fallback, optionally harmonized with the platform's dynamic
/// color scheme (Android 12+) for the neutral/system roles. StudyFlow's
/// signature indigo always remains the primary so the product keeps its
/// identity on every platform.
ColorScheme _buildScheme(Brightness brightness, ColorScheme? dynamicScheme) {
  final isDark = brightness == Brightness.dark;
  final seed = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: brightness,
  );
  return (dynamicScheme ?? seed).copyWith(
    // Light-mode primary is the AA-tuned indigo (4.5:1+ on white); dark
    // mode uses the lighter indigo so it reads against near-black.
    primary: isDark ? AppColors.indigoLight : const Color(0xFF5B5FE0),
    onPrimary: isDark ? const Color(0xFF111114) : Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF2A2B5C)
        : const Color(0xFFE0E7FF),
    onPrimaryContainer: isDark
        ? const Color(0xFFE0E7FF)
        : const Color(0xFF1E1B4B),
    inversePrimary: isDark ? AppColors.indigo : AppColors.indigoLight,
    surfaceTint: isDark ? AppColors.indigoLight : AppColors.indigo,
    surface: isDark ? const Color(0xFF1A1A22) : AppColors.paper,
    onSurface: isDark ? const Color(0xFFF2F2F5) : AppColors.ink,
    onSurfaceVariant: isDark
        ? const Color(0xFF9DA0AA)
        : const Color(0xFF52525B),
    outlineVariant: isDark ? const Color(0xFF3E3E47) : const Color(0xFFCAC4D0),
    error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
    onErrorContainer: isDark
        ? const Color(0xFFFEE2E2)
        : const Color(0xFF7F1D1D),
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
ThemeData buildAppTheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
  final isDark = brightness == Brightness.dark;
  final scheme = _buildScheme(brightness, dynamicScheme);
  final text = _buildTextTheme(scheme);

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
    extensions: [isDark ? GlassTheme.dark : GlassTheme.light],
  );
}
