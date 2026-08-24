import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/swiss/swiss_components.dart';

/// Settings screen — Swiss structured list.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;

    return Material(
      color: bg,
      child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              icon: Icon(Icons.arrow_back, size: 24, color: fg),
              onPressed: () => context.popOrHome(),
            ),
            const SizedBox(height: SwissSpacing.lg),

            // Header
            const SwissEyebrow(text: 'Settings'),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'SETTINGS',
              style: SwissTypography.headline.copyWith(color: fg),
            ),

            const SizedBox(height: SwissSpacing.xxxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Account
            const SwissSectionLabel(number: '01', title: 'Account'),
            const SizedBox(height: SwissSpacing.md),
            _SettingsItem(
              icon: Icons.person,
              label: 'Profile',
              onTap: () => context.push(AppRoutes.profile),
            ),
            const _SettingsItem(icon: Icons.lock, label: 'Password'),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Study
            const SwissSectionLabel(number: '02', title: 'Study'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(icon: Icons.school, label: 'AI Preferences'),
            const _SettingsItem(icon: Icons.language, label: 'Language'),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Audio
            const SwissSectionLabel(number: '03', title: 'Audio'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(
              icon: Icons.headphones,
              label: 'Podcast settings',
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Notifications
            const SwissSectionLabel(number: '04', title: 'Notifications'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(
              icon: Icons.notifications,
              label: 'Push notifications',
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Appearance
            const SwissSectionLabel(number: '05', title: 'Appearance'),
            const SizedBox(height: SwissSpacing.md),
            _AppearanceSetting(
              currentMode: themeMode,
              onModeChanged: (mode) {
                ref.read(themeModeProvider.notifier).setMode(mode);
              },
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Privacy
            const SwissSectionLabel(number: '06', title: 'Privacy'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(
              icon: Icons.privacy_tip,
              label: 'Privacy policy',
            ),
            const _SettingsItem(
              icon: Icons.description,
              label: 'Terms of service',
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Subscription
            const SwissSectionLabel(number: '07', title: 'Subscription'),
            const SizedBox(height: SwissSpacing.md),
            _SettingsItem(
              icon: Icons.star,
              label: 'Manage subscription',
              onTap: () => context.push(AppRoutes.premium),
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // About
            const SwissSectionLabel(number: '08', title: 'About'),
            const SizedBox(height: SwissSpacing.md),
            _SettingsItem(
              icon: Icons.system_update,
              label: 'Software Update',
              onTap: () => context.push(AppRoutes.softwareUpdate),
            ),
            _SettingsItem(
              icon: Icons.info,
              label: 'About StudyFlow',
              onTap: () => context.push(AppRoutes.aboutCreator),
            ),
            _SettingsItem(
              icon: Icons.code,
              label: 'Creator',
              onTap: () => context.push(AppRoutes.aboutCreator),
            ),

            const SizedBox(height: SwissSpacing.huge),
          ],
        ),
      ),
    ),
    );
  }
}

/// Settings list item — Swiss style.
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.4)
        : SwissColors.black.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: SwissSpacing.md),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: SwissTypography.label.copyWith(color: fg),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: mutedFg),
          ],
        ),
      ),
    );
  }
}

/// Appearance setting — theme toggle.
class _AppearanceSetting extends StatelessWidget {
  const _AppearanceSetting({
    required this.currentMode,
    required this.onModeChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final mode in ThemeMode.values)
          _ThemeOption(
            label: mode.name.toUpperCase(),
            selected: currentMode == mode,
            onTap: () => onModeChanged(mode),
          ),
      ],
    );
  }
}

/// Theme option — Swiss radio style.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;
    final iconData = switch (label) {
      'SYSTEM' => Icons.phone_android,
      'LIGHT' => Icons.light_mode,
      'DARK' => Icons.dark_mode,
      _ => Icons.circle,
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SwissSpacing.md),
        margin: const EdgeInsets.only(bottom: SwissSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? fg : bg,
          border: Border.all(
            color: selected ? (isDark ? SwissColors.white : SwissColors.black) : fg,
            width: SwissShapes.borderThin,
          ),
        ),
        child: Row(
          children: [
            Icon(
              iconData,
              size: 20,
              color: selected ? bg : fg,
            ),
            const SizedBox(width: SwissSpacing.md),
            Text(
              label,
              style: SwissTypography.label.copyWith(
                color: selected ? bg : fg,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check, size: 18, color: bg),
          ],
        ),
      ),
    );
  }
}
