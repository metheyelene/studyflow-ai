import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_info.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';
import '../premium/premium_controller.dart';

/// Profile tab: signed-in identity and sign-out, plan card, and the
/// Settings / About StudyFlow → Creator paths.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final auth = ref.watch(authControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (auth is AuthAuthenticated)
                  _IdentityCard(user: auth.user)
                else
                  const _SignedOutCard(),
                const SizedBox(height: 16),
                _PlanCard(),
                const SizedBox(height: 16),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      GlassListTile(
                        title: 'Settings',
                        subtitle: 'Profile, preferences, account',
                        leading: Icon(
                          Icons.settings,
                          size: 22,
                          color: g.primary,
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: g.textMuted,
                        ),
                        onTap: () => context.go(AppRoutes.settings),
                      ),
                      Divider(
                        color: g.textPrimary.withValues(alpha: 0.06),
                        height: 1,
                        indent: 50,
                      ),
                      GlassListTile(
                        title: 'About StudyFlow',
                        subtitle: 'About the app and its creator',
                        leading: Icon(Icons.info, size: 22, color: g.primary),
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
                if (auth is AuthAuthenticated &&
                    auth.user.email == AppInfo.founderEmail) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: GlassListTile(
                      title: 'Founder Dashboard',
                      subtitle: 'Users, subscriptions, revenue',
                      leading: Icon(
                        Icons.query_stats,
                        size: 22,
                        color: g.primary,
                      ),
                      trailing: Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: g.textMuted,
                      ),
                      onTap: () => launchUrl(
                        Uri.parse('${AppConfig.webAppUrl}/admin'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                ],
                if (auth is AuthAuthenticated) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: GlassListTile(
                      title: 'Sign out',
                      subtitle: 'End this session on this device',
                      leading: Icon(Icons.logout, size: 22, color: g.danger),
                      onTap: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live plan card: reads the user's plan from the backend and links to
/// the Premium screen. Honest loading/error fallbacks — no hard-coded
/// plan state.
class _PlanCard extends ConsumerWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(premiumControllerProvider);
    final (plan, badge) = state.when(
      loading: () => ('Loading…', 'Free'),
      error: (_, _) => ('Unavailable', 'Free'),
      data: (s) => (
        switch (s.plan) {
          'founding_member' => 'Founding Member',
          'premium' => 'Premium',
          _ => 'Free',
        },
        switch (s.plan) {
          'founding_member' => 'Founding Member',
          'premium' => 'Premium',
          _ => 'Free',
        },
      ),
    );
    final premium = state.value?.isPremium ?? false;
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(AppRoutes.premium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                premium ? Icons.workspace_premium : Icons.workspace_premium,
                size: 20,
                color: premium ? g.primary : g.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StudyFlow Premium',
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan,
                      style: TextStyle(color: g.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              GlassBadge(
                label: badge,
                icon: premium ? Icons.workspace_premium : null,
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: g.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: g.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: TextStyle(
                color: g.primary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(user.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(user.email, style: TextStyle(color: g.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
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
          Text(
            'Sign in to get started',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Your plan, preferences, and study data live here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
