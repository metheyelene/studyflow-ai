import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';

/// Profile screen — Swiss editorial identity page.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const SwissEyebrow(text: 'Profile'),
            const SizedBox(height: SwissSpacing.sm),

            // User info
            if (auth is AuthAuthenticated) ...[
              Text(
                auth.user.name.toUpperCase(),
                style: SwissTypography.headline.copyWith(color: fg),
              ),
              const SizedBox(height: SwissSpacing.xs),
              Text(
                auth.user.email,
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
            ] else ...[
              Text(
                'GUEST',
                style: SwissTypography.headline.copyWith(color: fg),
              ),
            ],

            const SizedBox(height: SwissSpacing.xxxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxxl),

            // Study statistics
            const SwissSectionLabel(number: '01', title: 'Study stats'),
            const SizedBox(height: SwissSpacing.md),
            SwissCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAK',
                    style: SwissTypography.label.copyWith(color: fg),
                  ),
                  const SizedBox(height: SwissSpacing.xs),
                  Text(
                    '0 DAYS',
                    style: SwissTypography.section.copyWith(color: fg),
                  ),
                ],
              ),
            ),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // Settings sections
            const SwissSectionLabel(number: '02', title: 'Settings'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(icon: Icons.person, label: 'Account'),
            const _SettingsItem(icon: Icons.palette, label: 'Appearance'),
            const _SettingsItem(icon: Icons.notifications, label: 'Notifications'),
            const _SettingsItem(icon: Icons.privacy_tip, label: 'Privacy'),

            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(),
            const SizedBox(height: SwissSpacing.xxl),

            // About
            const SwissSectionLabel(number: '03', title: 'About'),
            const SizedBox(height: SwissSpacing.md),
            const _SettingsItem(icon: Icons.info, label: 'About StudyFlow'),
            const _SettingsItem(icon: Icons.code, label: 'Creator'),

            const SizedBox(height: SwissSpacing.xxxl),

            // Sign out
            SwissButton(
              label: 'Sign out',
              variant: SwissButtonVariant.secondary,
              fullWidth: true,
              onPressed: () {
                // TODO: Sign out
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings list item — Swiss style.
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.4)
        : SwissColors.black.withValues(alpha: 0.4);

    return InkWell(
      onTap: () {},
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
            Icon(Icons.chevron_right, size: 20, color: mutedFg),
          ],
        ),
      ),
    );
  }
}
