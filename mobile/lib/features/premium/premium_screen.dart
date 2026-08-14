import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import 'play_billing_repository.dart';
import 'premium_controller.dart';

/// StudyFlow Premium — the founding-member offer and the full plan.
///
/// Everything displayed is backend-derived: the plan comes from
/// GET /api/usage, the remaining founding slots from
/// GET /api/billing/founding-status, and the price from Play's product
/// details. Purchases are verified server-side — a local purchase
/// callback alone never unlocks anything.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  static const _features = [
    'Advanced AI Study Tutor',
    'Smart Study Mode',
    'Advanced PDF Intelligence',
    'Adaptive Quizzes & Smart Flashcards',
    'Exam Simulation & Mistake Intelligence',
    'Advanced Progress Analytics',
    'Audio Study Podcasts',
    'Higher AI usage limits',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(premiumControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                      Expanded(
                        child: Text(
                          'StudyFlow Premium',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  state.when(
                    loading: () => const Column(
                      children: [
                        GlassSkeleton(height: 120),
                        SizedBox(height: 16),
                        GlassSkeleton(height: 240),
                      ],
                    ),
                    error: (err, _) => _ErrorCard(onRetry: () {
                      ref
                          .read(premiumControllerProvider.notifier)
                          .refresh();
                    }),
                    data: (snapshot) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlanCard(snapshot: snapshot),
                        const SizedBox(height: 16),
                        if (snapshot.founding.offerActive)
                          _FoundingOfferCard(snapshot: snapshot)
                        else
                          _PremiumCard(snapshot: snapshot),
                        const SizedBox(height: 16),
                        _PurchaseCard(snapshot: snapshot),
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

String _planLabel(String plan) => switch (plan) {
  'founding_member' => 'Founding Member',
  'premium' => 'Premium',
  _ => 'Free',
};

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.snapshot});

  final PremiumSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Row(
        children: [
          Icon(
            snapshot.isPremium
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            size: 28,
            color: snapshot.isPremium ? g.primary : g.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your plan',
                  style: TextStyle(color: g.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _planLabel(snapshot.plan),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          if (snapshot.isPremium)
            GlassBadge(label: 'Active', icon: Icons.check_circle),
        ],
      ),
    );
  }
}

class _FoundingOfferCard extends StatelessWidget {
  const _FoundingOfferCard({required this.snapshot});

  final PremiumSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final price = snapshot.priceLabel ?? '\$2';
    final remaining = snapshot.founding.remaining;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GlassBadge(
                  label: 'Founding Member',
                  icon: Icons.auto_awesome,
                  color: g.primary,
                ),
              ),
              if (remaining != null)
                Flexible(
                  child: Text(
                    '$remaining of ${snapshot.founding.cap} left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: g.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ month',
                  style: TextStyle(color: g.textMuted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The founding price for the first ${snapshot.founding.cap} members. '
            'Your price stays the same for as long as you keep the subscription.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final feature in PremiumScreen._features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: g.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.snapshot});

  final PremiumSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final heading = snapshot.founding.available
        ? 'The founding offer is complete'
        : 'StudyFlow Premium';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.founding.available
                ? 'All ${snapshot.founding.cap} founding memberships have been '
                      'claimed. Premium is now available at its regular price.'
                : 'The full Premium experience, whenever you are ready for it.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final feature in PremiumScreen._features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: g.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PurchaseCard extends ConsumerWidget {
  const _PurchaseCard({required this.snapshot});

  final PremiumSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final controller = ref.read(premiumControllerProvider.notifier);
    final busy = ref.watch(_purchaseBusyProvider);
    final onAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    Future<void> subscribe() async {
      if (busy) return;
      ref.read(_purchaseBusyProvider.notifier).set(true);
      try {
        if (onAndroid) {
          final result = await controller.purchaseFounding();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.ok
                    ? 'Welcome to StudyFlow Premium.'
                    : (result.message ?? "StudyFlow couldn't complete that purchase."),
              ),
            ),
          );
        } else if (kIsWeb) {
          final url = await controller.webCheckoutUrl();
          if (!context.mounted) return;
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Subscriptions will be available with the App Store launch.',
              ),
            ),
          );
        }
      } on BillingException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("StudyFlow couldn't complete that request.")),
        );
      } finally {
        ref.read(_purchaseBusyProvider.notifier).set(false);
      }
    }

    Future<void> restore() async {
      if (busy) return;
      ref.read(_purchaseBusyProvider.notifier).set(true);
      try {
        final granted = await controller.restorePurchases();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted.isEmpty
                  ? 'No purchases found to restore on this device.'
                  : 'Restored: ${granted.map(_planLabel).join(', ')}.',
            ),
          ),
        );
      } finally {
        ref.read(_purchaseBusyProvider.notifier).set(false);
      }
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onAndroid)
            GlassButton(
              label: snapshot.isPremium
                  ? 'Manage Subscription'
                  : (snapshot.founding.offerActive
                        ? 'Subscribe — Founding Member'
                        : 'Subscribe to Premium'),
              icon: Icons.workspace_premium,
              expand: true,
              onPressed: busy
                  ? null
                  : () async {
                      if (snapshot.isPremium) {
                        // Play handles subscription management in-app.
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Manage your subscription in Google Play: '
                              'Play Store → Subscriptions.',
                            ),
                          ),
                        );
                        return;
                      }
                      await subscribe();
                    },
            ),
          if (kIsWeb)
            GlassButton(
              label: 'Subscribe on web',
              icon: Icons.language,
              variant: GlassButtonVariant.primary,
              expand: true,
              onPressed: busy ? null : subscribe,
            ),
          if (!onAndroid && !kIsWeb)
            GlassButton(
              label: 'Subscribe — arriving with the App Store launch',
              variant: GlassButtonVariant.glass,
              expand: true,
              onPressed: null,
            ),
          const SizedBox(height: 10),
          GlassButton(
            label: 'Restore Purchases',
            icon: Icons.restore,
            variant: GlassButtonVariant.glass,
            expand: true,
            onPressed: busy ? null : restore,
          ),
          const SizedBox(height: 10),
          Text(
            'Subscriptions auto-renew until cancelled. You can cancel any '
            'time from Google Play. Entitlements are verified server-side — '
            'your purchase stays with your account across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.textMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Tracks an in-flight purchase so double-taps cannot double-submit.
final _purchaseBusyProvider =
    NotifierProvider<_PurchaseBusy, bool>(_PurchaseBusy.new);

class _PurchaseBusy extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 40, color: g.textMuted),
          const SizedBox(height: 10),
          Text(
            "StudyFlow couldn't load your subscription.",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Please check your connection and try again.',
            style: TextStyle(color: g.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'Try Again',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
