import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/semantics.dart';

import 'core/config/app_config.dart';
import 'core/config/capture_seed.dart';
import 'core/routing/app_router.dart';
import 'core/theme/swiss_tokens.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  if (AppConfig.captureMode) {
    SemanticsBinding.instance.ensureSemantics();
  }

  runApp(
    ProviderScope(
      overrides: AppConfig.captureMode ? captureOverrides : const [],
      child: const StudyFlowApp(),
    ),
  );
}

class StudyFlowApp extends ConsumerStatefulWidget {
  const StudyFlowApp({super.key});

  @override
  ConsumerState<StudyFlowApp> createState() => _StudyFlowAppState();
}

class _StudyFlowAppState extends ConsumerState<StudyFlowApp> {
  @override
  void initState() {
    super.initState();
    ref.read(authControllerProvider.notifier).restore();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'StudyFlow AI',
      debugShowCheckedModeBanner: false,
      theme: _buildSwissTheme(Brightness.light),
      darkTheme: _buildSwissTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }

  /// Swiss International theme — Black, White, Red only.
  ThemeData _buildSwissTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? SwissColors.darkBackground
        : SwissColors.background;
    final surface = isDark ? SwissColors.darkSurface : SwissColors.surface;
    final onSurface = isDark
        ? SwissColors.darkOnSurface
        : SwissColors.onSurface;
    final border = isDark ? SwissColors.darkBorder : SwissColors.border;
    final muted = isDark ? SwissColors.darkMuted : SwissColors.muted;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? SwissColors.white : SwissColors.black,
        onPrimary: isDark ? SwissColors.black : SwissColors.white,
        secondary: isDark ? SwissColors.white : SwissColors.black,
        onSecondary: isDark ? SwissColors.black : SwissColors.white,
        tertiary: SwissColors.red,
        onTertiary: SwissColors.white,
        surface: surface,
        onSurface: onSurface,
        error: SwissColors.red,
        onError: SwissColors.white,
      ),

      textTheme: TextTheme(
        displayLarge: SwissTypography.display.copyWith(color: onSurface),
        displayMedium: SwissTypography.headline.copyWith(color: onSurface),
        displaySmall: SwissTypography.section.copyWith(color: onSurface),
        headlineLarge: SwissTypography.headline.copyWith(color: onSurface),
        headlineMedium: SwissTypography.section.copyWith(color: onSurface),
        headlineSmall: SwissTypography.subheading.copyWith(color: onSurface),
        titleLarge: SwissTypography.subheading.copyWith(color: onSurface),
        titleMedium: SwissTypography.bodyBold.copyWith(color: onSurface),
        titleSmall: SwissTypography.caption.copyWith(color: onSurface),
        bodyLarge: SwissTypography.body.copyWith(color: onSurface),
        bodyMedium: SwissTypography.body.copyWith(
          color: onSurface.withValues(alpha: 0.7),
        ),
        bodySmall: SwissTypography.caption.copyWith(
          color: onSurface.withValues(alpha: 0.5),
        ),
        labelLarge: SwissTypography.label.copyWith(color: onSurface),
        labelMedium: SwissTypography.label.copyWith(
          color: onSurface.withValues(alpha: 0.6),
        ),
        labelSmall: SwissTypography.caption.copyWith(
          color: onSurface.withValues(alpha: 0.4),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: SwissTypography.subheading.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: SwissShapes.borderThin),
          borderRadius: BorderRadius.zero,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        hintStyle: SwissTypography.body.copyWith(
          color: onSurface.withValues(alpha: 0.4),
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: SwissColors.black,
            width: SwissShapes.borderThin,
          ),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: SwissColors.black,
            width: SwissShapes.borderThin,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: SwissColors.red,
            width: SwissShapes.borderThin,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: SwissShapes.borderThin,
        space: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: SwissShapes.borderThin),
          borderRadius: BorderRadius.zero,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? SwissColors.white : SwissColors.black,
        contentTextStyle: SwissTypography.body.copyWith(
          color: isDark ? SwissColors.black : SwissColors.white,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
