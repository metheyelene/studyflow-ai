import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';
import '../notebooks/notebook.dart';
import '../notebooks/notebooks_controller.dart';
import 'dashboard_controller.dart';

/// Home tab — Bauhaus editorial command center.
///
/// Composition: greeting → hero with geometric composition →
/// recent spaces on hairlines → quick actions → upcoming exams.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final firstName = auth is AuthAuthenticated
        ? auth.user.name.trim().split(' ').first
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          BauhausSpacing.xl,
          BauhausSpacing.xl,
          BauhausSpacing.xl,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Section ────────────────────────────────────
            _BauhausHero(firstName: firstName),
            const SizedBox(height: BauhausSpacing.xxxl),

            // ── Usage Bar ───────────────────────────────────────
            _UsageBar(dashboard: dashboard),
            const SizedBox(height: BauhausSpacing.xxxl),

            // ── Recent Spaces ───────────────────────────────────
            const BauhausSectionHeading(title: 'Recent'),
            const SizedBox(height: BauhausSpacing.md),
            const _RecentSpaces(),
            const SizedBox(height: BauhausSpacing.xxxl),

            // ── Quick Actions ───────────────────────────────────
            const BauhausSectionHeading(title: 'Quick'),
            const SizedBox(height: BauhausSpacing.md),
            const _QuickActions(),
            const SizedBox(height: BauhausSpacing.xxxl),

            // ── Upcoming Exams ──────────────────────────────────
            const BauhausSectionHeading(title: 'Upcoming'),
            const SizedBox(height: BauhausSpacing.md),
            _UpcomingExams(dashboard: dashboard),
          ],
        ),
      ),
    );
  }
}

/// Bauhaus hero — massive greeting + geometric composition.
class _BauhausHero extends StatelessWidget {
  const _BauhausHero({this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        const BauhausEyebrow(text: 'Welcome back'),
        const SizedBox(height: BauhausSpacing.sm),

        // Name in display type
        Text(
          firstName ?? 'Friend',
          style: BauhausTypography.hero,
        ),

        const SizedBox(height: BauhausSpacing.sm),

        // Tagline
        Text(
          'Ready to study?',
          style: BauhausTypography.bodyMuted.copyWith(
            color: BauhausColors.black.withValues(alpha: 0.6),
          ),
        ),

        const SizedBox(height: BauhausSpacing.xxl),

        // Geometric composition — asymmetric, bold
        const BauhausComposition(
          width: 280,
          height: 160,
          circleColor: BauhausColors.blue,
          squareColor: BauhausColors.yellow,
          triangleColor: BauhausColors.red,
        ),
      ],
    );
  }
}

/// Usage bar — thin monochrome progress.
class _UsageBar extends ConsumerWidget {
  const _UsageBar({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return dashboard.when(
      loading: () => Container(
        height: 20,
        decoration: BoxDecoration(
          color: BauhausColors.muted,
          border: Border.all(
            color: BauhausColors.black,
            width: BauhausShapes.borderThin,
          ),
        ),
      ),
      error: (_, _) => BauhausErrorState(
        title: 'Error',
        message: 'Could not load your usage.',
        onRetry: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
      ),
      data: (snapshot) {
        final usage = snapshot.usage;
        final planLabel = switch (usage.plan) {
          'premium' => 'Premium',
          'founding_member' => 'Founding member',
          _ => 'Free plan',
        };
        final remaining = usage.remaining;
        final frac = (usage.percent / 100).clamp(0.0, 1.0);

        return BauhausCard(
          accent: BauhausCardAccent.circle,
          accentColor: BauhausColors.blue,
          padding: const EdgeInsets.all(BauhausSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$remaining',
                    style: BauhausTypography.headline.copyWith(fontSize: 28),
                  ),
                  const SizedBox(width: BauhausSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI actions left',
                      style: BauhausTypography.bodyMuted.copyWith(
                        color: BauhausColors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  BauhausEyebrow(text: planLabel),
                ],
              ),
              const SizedBox(height: BauhausSpacing.md),
              BauhausLine(height: 4, color: BauhausColors.muted),
              const SizedBox(height: BauhausSpacing.xs),
              SizedBox(
                height: 8,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: const BauhausLine(color: BauhausColors.black),
                ),
              ),
              const SizedBox(height: BauhausSpacing.xs),
              Text(
                'Resets on the 1st',
                style: BauhausTypography.caption.copyWith(
                  color: BauhausColors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Recent study spaces — numbered editorial list.
class _RecentSpaces extends ConsumerWidget {
  const _RecentSpaces();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notebooksControllerProvider);
    return state.when(
      loading: () => const BauhausProcessingState(label: 'Loading'),
      error: (_, _) => BauhausErrorState(
        title: 'Error',
        message: 'Could not load your study spaces.',
      ),
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return BauhausEmptyState(
            title: 'No study spaces',
            description: 'Create your first study space to get started.',
            actionLabel: 'Create',
            onAction: () => context.go(AppRoutes.notebooks),
            composition: const BauhausComposition(
              width: 120,
              height: 120,
              circleColor: BauhausColors.blue,
              squareColor: BauhausColors.yellow,
              triangleColor: BauhausColors.red,
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < notebooks.length; i++) ...[
              _SpaceRow(index: i + 1, notebook: notebooks[i]),
              if (i != notebooks.length - 1) const BauhausHairline(),
            ],
          ],
        );
      },
    );
  }
}

/// One notebook row — index numeral, title, source count.
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({required this.index, required this.notebook});

  final int index;
  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final count = notebook.sourceCount;
    return InkWell(
      onTap: () => context.push('/notebooks/${notebook.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BauhausSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: BauhausTypography.label.copyWith(
                  color: BauhausColors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BauhausTypography.subheading,
                  ),
                  const SizedBox(height: BauhausSpacing.xxs),
                  Text(
                    count == 1 ? '1 source' : '$count sources',
                    style: BauhausTypography.caption.copyWith(
                      color: BauhausColors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
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

/// Quick actions — Bauhaus buttons.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    (Icons.auto_awesome, 'Ask AI', AppRoutes.notebooks, true),
    (Icons.style, 'Flashcards', AppRoutes.flashcards, false),
    (Icons.quiz, 'Quiz', AppRoutes.quizzes, false),
    (Icons.mic, 'Podcast', AppRoutes.audio, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BauhausSpacing.sm,
      runSpacing: BauhausSpacing.sm,
      children: [
        for (final action in _actions)
          BauhausButton(
            label: action.$2,
            icon: action.$1,
            variant: BauhausButtonVariant.outline,
            size: BauhausButtonSize.medium,
            onPressed: () {
              action.$4 ? context.go(action.$3) : context.push(action.$3);
            },
          ),
      ],
    );
  }
}

/// Upcoming exams — Bauhaus cards.
class _UpcomingExams extends ConsumerWidget {
  const _UpcomingExams({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return dashboard.when(
      loading: () => const BauhausProcessingState(label: 'Loading exams'),
      error: (_, _) => BauhausErrorState(
        title: 'Error',
        message: 'Could not load your exams.',
        onRetry: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
      ),
      data: (snapshot) {
        if (snapshot.exams.isEmpty) {
          return BauhausCard(
            accent: BauhausCardAccent.triangle,
            accentColor: BauhausColors.yellow,
            child: Column(
              children: [
                const BauhausSquare(
                  size: 48,
                  color: BauhausColors.muted,
                  strokeWidth: 2,
                ),
                const SizedBox(height: BauhausSpacing.md),
                Text(
                  'NO UPCOMING EXAMS',
                  style: BauhausTypography.subheading,
                ),
                const SizedBox(height: BauhausSpacing.xs),
                Text(
                  'Exams from your study setup appear here.',
                  textAlign: TextAlign.center,
                  style: BauhausTypography.bodyMuted.copyWith(
                    color: BauhausColors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final exam in snapshot.exams)
              BauhausCard(
                accent: BauhausCardAccent.triangle,
                accentColor: BauhausColors.red,
                onTap: () {},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title.toUpperCase(),
                      style: BauhausTypography.subheading,
                    ),
                    const SizedBox(height: BauhausSpacing.xs),
                    Text(
                      '${exam.daysUntil} days remaining',
                      style: BauhausTypography.bodyMuted.copyWith(
                        color: BauhausColors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
