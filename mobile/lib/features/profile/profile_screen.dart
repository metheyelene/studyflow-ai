import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';

/// Profile tab. Auth wiring arrives with the API client (Phase 4); this
/// already surfaces Settings and the About StudyFlow → Creator path.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: g.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 32, color: g.primary),
                      ),
                      const SizedBox(height: 10),
                      Text('Sign in to get started', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Your plan, preferences, and study data live here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: g.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.workspace_premium_outlined, size: 20, color: g.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your plan',
                                  style: TextStyle(
                                    color: g.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Free · founding-member offer arrives with payments.',
                                  style: TextStyle(color: g.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          GlassBadge(
                            label: 'Free',
                            icon: Icons.check_circle_outline,
                          ),
                        ],
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
                        title: 'Settings',
                        subtitle: 'Profile, preferences, account',
                        leading: Icon(Icons.settings_outlined, size: 22, color: g.primary),
                        trailing: Icon(Icons.chevron_right, size: 20, color: g.textMuted),
                        onTap: () => context.go(AppRoutes.settings),
                      ),
                      const Divider(color: Color(0x14000000), height: 1, indent: 50),
                      GlassListTile(
                        title: 'About StudyFlow',
                        subtitle: 'About the app and its creator',
                        leading: Icon(Icons.info_outline, size: 22, color: g.primary),
                        trailing: Icon(Icons.chevron_right, size: 20, color: g.textMuted),
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
    );
  }
}
