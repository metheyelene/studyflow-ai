import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';

/// Profile screen — Bauhaus editorial identity page.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Profile'),
            const SizedBox(height: BauhausSpacing.sm),

            // User info
            if (auth is AuthAuthenticated) ...[
              Text(
                auth.user.name.toUpperCase(),
                style: BauhausTypography.headline,
              ),
              const SizedBox(height: BauhausSpacing.xs),
              Text(
                auth.user.email,
                style: BauhausTypography.bodyMuted.copyWith(
                  color: BauhausColors.black.withValues(alpha: 0.6),
                ),
              ),
            ] else ...[
              Text(
                'GUEST',
                style: BauhausTypography.headline,
              ),
            ],

            const SizedBox(height: BauhausSpacing.xxxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxxl),

            // Study statistics
            const BauhausSectionHeading(title: 'Study stats'),
            const SizedBox(height: BauhausSpacing.md),
            BauhausCard(
              accent: BauhausCardAccent.circle,
              accentColor: BauhausColors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAK',
                    style: BauhausTypography.label,
                  ),
                  const SizedBox(height: BauhausSpacing.xs),
                  Text(
                    '0 DAYS',
                    style: BauhausTypography.section,
                  ),
                ],
              ),
            ),

            const SizedBox(height: BauhausSpacing.xxl),
            const BauhausDivider(),
            const SizedBox(height: BauhausSpacing.xxl),

            // Settings sections
            const BauhausSectionHeading(title: 'Settings'),
            const SizedBox(height: BauhausSpacing.md),
            _SettingsItem(
              icon: Icons.person,
              label: 'Account',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.palette,
              label: 'Appearance',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.notifications,
              label: 'Notifications',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.privacy_tip,
              label: 'Privacy',
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

            const SizedBox(height: BauhausSpacing.xxxl),

            // Sign out
            BauhausButton(
              label: 'Sign out',
              variant: BauhausButtonVariant.outline,
              expand: true,
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
