import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';

/// Settings — profile editing and account actions arrive with auth
/// (Phase 4). About StudyFlow → Creator is available now.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
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
                        onPressed: () => context.pop(),
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
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: () => showGlassToast(
                            context,
                            'Theme switching arrives soon.',
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
