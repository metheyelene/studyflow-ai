import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';

/// Settings screen — Bauhaus structured list.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Settings'),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              'SETTINGS',
              style: BauhausTypography.headline,
            ),

            const SizedBox(height: BauhausSpacing.xxxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Account
            const BauhausSectionHeading(title: 'Account'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.person,
              label: 'Profile',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.lock,
              label: 'Password',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Study
            const BauhausSectionHeading(title: 'Study'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.school,
              label: 'AI Preferences',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.language,
              label: 'Language',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Audio
            const BauhausSectionHeading(title: 'Audio'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.headphones,
              label: 'Podcast settings',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Notifications
            const BauhausSectionHeading(title: 'Notifications'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.notifications,
              label: 'Push notifications',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Appearance
            const BauhausSectionHeading(title: 'Appearance'),
            const SizedBox(height: BauhausSpacing.md),
            _AppearanceSetting(
              currentMode: themeMode,
              onModeChanged: (mode) {
                ref.read(themeModeProvider.notifier).setMode(mode);
              },
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Privacy
            const BauhausSectionHeading(title: 'Privacy'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.privacy_tip,
              label: 'Privacy policy',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.description,
              label: 'Terms of service',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Subscription
            const BauhausSectionHeading(title: 'Subscription'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.star,
              label: 'Manage subscription',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // About
            const BauhausSectionHeading(title: 'About'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.info,
              label: 'About StudyFlow',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.code,
              label: 'Creator',
              onTap: () {},
            ),

            const SizedBox(height: BauhausSpacing.huge),
          ],
        ),
      ),
    );
  }
}

/// Settings list item — Bauhaus style.
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BauhausSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: BauhausColors.black),
            const SizedBox(width: BauhausSpacing.md),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: BauhausTypography.label,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: BauhausColors.black,
            ),
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

/// Theme option — Bauhaus radio style.
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(BauhausSpacing.md),
        margin: const EdgeInsets.only(bottom: BauhausSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? BauhausColors.black : BauhausColors.white,
          border: Border.all(
            color: BauhausColors.black,
            width: BauhausShapes.borderMedium,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: BauhausTypography.label.copyWith(
                color: selected ? BauhausColors.white : BauhausColors.black,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(
                Icons.check,
                size: 18,
                color: BauhausColors.white,
              ),
          ],
        ),
      ),
    );
  }
}
