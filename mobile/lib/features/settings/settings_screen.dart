import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';

/// Settings — appearance (light/dark/system) and About StudyFlow → Creator.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showAppearance = false;

  void _toggleAppearance() => setState(() => _showAppearance = !_showAppearance);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.popOrHome(),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        GlassListTile(
                          title: 'Profile',
                          subtitle: 'Name, study level, preferences',
                          leading: Icon(
                            Icons.person_outline,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: () => showGlassToast(
                            context,
                            'Profile editing arrives with sign-in.',
                          ),
                        ),
                        const Divider(
                          color: Color(0x14000000),
                          height: 1,
                          indent: 50,
                        ),
                        GlassListTile(
                          title: 'Appearance',
                          subtitle: 'Light / dark / system',
                          leading: Icon(
                            Icons.palette_outlined,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                switch (themeMode) {
                                  ThemeMode.light => 'Light',
                                  ThemeMode.dark => 'Dark',
                                  ThemeMode.system => 'System',
                                },
                                style: AppText.small.copyWith(
                                  color: g.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAppearance
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: g.textMuted,
                              ),
                            ],
                          ),
                          onTap: _toggleAppearance,
                        ),
                        if (_showAppearance)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text('Dark'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto_outlined),
                                  label: Text('System'),
                                ),
                              ],
                              selected: {themeMode},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(selection.first),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        GlassListTile(
                          title: 'About StudyFlow',
                          subtitle: 'About the app and its creator',
                          leading: Icon(
                            Icons.info_outline,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: () => context.go(AppRoutes.aboutCreator),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
