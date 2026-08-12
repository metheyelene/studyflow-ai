import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/semantics.dart';

import 'core/config/app_config.dart';
import 'core/config/capture_seed.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Serve real paths on web (no-op on mobile) so deep links like
  // `/about/creator` — the landing footer's "Made by Mithil" href — open
  // the matching route directly instead of requiring a `#/` hash.
  usePathUrlStrategy();

  // Screenshot-capture builds: expose the semantics tree so the driver can
  // click real widgets, and swap in seeded in-memory repositories. Never
  // enabled in normal or release builds.
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
    // Restore the session: re-attach the persisted token and validate it.
    // Until it resolves the router shows the splash.
    ref.read(authControllerProvider.notifier).restore();
  }

  @override
  Widget build(BuildContext context) {
    // Android 12+ supplies a dynamic color scheme from the wallpaper; iOS and
    // older Android fall back to the branded seed palette in buildAppTheme.
    // The theme mode (light / dark / system) is user-controlled from
    // Settings → Appearance and persisted locally.
    final themeMode = ref.watch(themeModeProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'StudyFlow AI',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light, dynamicScheme: lightDynamic),
          darkTheme: buildAppTheme(Brightness.dark, dynamicScheme: darkDynamic),
          themeMode: themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
