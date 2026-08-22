import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/semantics.dart';

import 'core/config/app_config.dart';
import 'core/config/capture_seed.dart';
import 'core/routing/app_router.dart';
import 'core/theme/bauhaus_tokens.dart';
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
      theme: _buildBauhausTheme(Brightness.light),
      darkTheme: _buildBauhausTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }

  /// Build the Bauhaus theme — geometric, bold, constructivist.
  ThemeData _buildBauhausTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Bauhaus colors adapt to light/dark mode.
    final background = isDark ? const Color(0xFF121212) : BauhausColors.background;
    final surface = isDark ? const Color(0xFF1E1E1E) : BauhausColors.white;
    final onSurface = isDark ? BauhausColors.white : BauhausColors.black;
    final border = isDark
        ? BauhausColors.white.withValues(alpha: 0.2)
        : BauhausColors.black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? BauhausColors.white : BauhausColors.black,
        onPrimary: isDark ? BauhausColors.black : BauhausColors.white,
        secondary: BauhausColors.blue,
        onSecondary: BauhausColors.white,
        tertiary: BauhausColors.red,
        onTertiary: BauhausColors.white,
        surface: surface,
        onSurface: onSurface,
        error: BauhausColors.red,
        onError: BauhausColors.white,
      ),
      textTheme: TextTheme(
        displayLarge: BauhausTypography.hero.copyWith(color: onSurface),
        displayMedium: BauhausTypography.headline.copyWith(color: onSurface),
        displaySmall: BauhausTypography.section.copyWith(color: onSurface),
        headlineLarge: BauhausTypography.headline.copyWith(color: onSurface),
        headlineMedium: BauhausTypography.section.copyWith(color: onSurface),
        headlineSmall: BauhausTypography.subheading.copyWith(color: onSurface),
        titleLarge: BauhausTypography.subheading.copyWith(color: onSurface),
        titleMedium: BauhausTypography.body.copyWith(color: onSurface),
        titleSmall: BauhausTypography.caption.copyWith(color: onSurface),
        bodyLarge: BauhausTypography.body.copyWith(color: onSurface),
        bodyMedium: BauhausTypography.bodyMuted.copyWith(color: onSurface),
        bodySmall: BauhausTypography.caption.copyWith(color: onSurface),
        labelLarge: BauhausTypography.label.copyWith(color: onSurface),
        labelMedium: BauhausTypography.label.copyWith(color: onSurface),
        labelSmall: BauhausTypography.caption.copyWith(color: onSurface),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: BauhausTypography.subheading.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: BauhausShapes.borderMedium),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: isDark ? BauhausColors.white : BauhausColors.black,
        textTheme: ButtonTextTheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: border, width: BauhausShapes.borderThin),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border, width: BauhausShapes.borderThin),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? BauhausColors.white : BauhausColors.black,
            width: BauhausShapes.borderMedium,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: BauhausShapes.borderThin,
        space: 0,
      ),
    );
  }
}
