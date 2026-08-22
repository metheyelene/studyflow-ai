import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';
import '../notebooks/notebooks_controller.dart';
import 'dashboard_controller.dart';

/// Home tab — Swiss editorial command center.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final firstName = auth is AuthAuthenticated
        ? auth.user.name.trim().split(' ').first
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SwissSpacing.xl,
          SwissSpacing.xl,
          SwissSpacing.xl,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Section ────────────────────────────────────
            _SwissHero(firstName: firstName),
            const SizedBox(height: SwissSpacing.xxxl),

            // ── Usage Bar ───────────────────────────────────────
            const _UsageBar(),
            const SizedBox(height: SwissSpacing.xxxl),

            // ── Recent Spaces ───────────────────────────────────
            const SwissSectionLabel(number: '01', title: 'Recent'),
            const SizedBox(height: SwissSpacing.md),
            const _RecentSpaces(),
            const SizedBox(height: SwissSpacing.xxxl),

            // ── Quick Actions ───────────────────────────────────
            const SwissSectionLabel(number: '02', title: 'Quick'),
            const SizedBox(height: SwissSpacing.md),
            const _QuickActions(),
            const SizedBox(height: SwissSpacing.xxxl),

            // ── Upcoming Exams ──────────────────────────────────
            const SwissSectionLabel(number: '03', title: 'Upcoming'),
            const SizedBox(height: SwissSpacing.md),
            const _UpcomingExams(),
          ],
        ),
      ),
    );
  }
}

/// Swiss hero — massive greeting, flush left, no geometric shapes.
class _SwissHero extends StatelessWidget {
  const _SwissHero({this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SwissEyebrow(text: 'Welcome back'),
        const SizedBox(height: SwissSpacing.sm),
        Text(
          (firstName ?? 'Friend').toUpperCase(),
          style: SwissTypography.display.copyWith(color: fg),
        ),
        const SizedBox(height: SwissSpacing.sm),
        Text(
          'Ready to study?',
          style: SwissTypography.body.copyWith(color: mutedFg),
        ),
      ],
    );
  }
}

/// Usage bar — thin monochrome progress.
class _UsageBar extends ConsumerWidget {
  const _UsageBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final usageAsync = ref.watch(usageProvider);

    return usageAsync.when(
      loading: () => Container(
        height: 20,
        decoration: BoxDecoration(
          color: isDark ? SwissColors.darkMuted : SwissColors.muted,
          border: Border.all(
            color: fg,
            width: SwissShapes.borderThin,
          ),
        ),
      ),
      error: (e, _) => SwissErrorState(
        title: 'Usage',
        message: 'Could not load your usage.\n${e.toString().replaceAll('Exception: ', '')}',
        onRetry: () => ref.invalidate(usageProvider),
      ),
      data: (usage) {
        final planLabel = switch (usage.plan) {
          'premium' => 'Premium',
          'founding_member' => 'Founding member',
          _ => 'Free plan',
        };
        final remaining = usage.remaining;
        final frac = (usage.percent / 100).clamp(0.0, 1.0);

        return SwissCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$remaining',
                    style: SwissTypography.headline.copyWith(
                      fontSize: 28,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: SwissSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI actions left',
                      style: SwissTypography.body.copyWith(
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  SwissEyebrow(text: planLabel),
                ],
              ),
              const SizedBox(height: SwissSpacing.md),
              SwissProgressBar(value: frac),
              const SizedBox(height: SwissSpacing.xs),
              Text(
                'Resets on the 1st',
                style: SwissTypography.caption.copyWith(
                  color: fg.withValues(alpha: 0.5),
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
      loading: () => const SwissProcessingState(label: 'Loading'),
      error: (_, _) => SwissErrorState(
        title: 'Error',
        message: 'Could not load your study spaces.',
      ),
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return SwissEmptyState(
            sectionNumber: '01',
            title: 'No study spaces',
            description: 'Create your first study space to get started.',
            actionLabel: 'Create',
            onAction: () => context.go(AppRoutes.notebooks),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < notebooks.length; i++) ...[
              SwissNumberedItem(
                index: i + 1,
                title: notebooks[i].title,
                subtitle: notebooks[i].sourceCount == 1
                    ? '1 source'
                    : '${notebooks[i].sourceCount} sources',
                onTap: () => context.push('/notebooks/${notebooks[i].id}'),
              ),
              if (i != notebooks.length - 1) const SwissHairline(),
            ],
          ],
        );
      },
    );
  }
}

/// Quick actions — Swiss buttons.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SwissSpacing.sm,
      runSpacing: SwissSpacing.sm,
      children: [
        SwissButton(
          label: 'Ask AI',
          icon: Icons.auto_awesome,
          variant: SwissButtonVariant.primary,
          onPressed: () => context.go(AppRoutes.notebooks),
        ),
        SwissButton(
          label: 'Flashcards',
          icon: Icons.style,
          variant: SwissButtonVariant.secondary,
          onPressed: () => context.push(AppRoutes.flashcards),
        ),
        SwissButton(
          label: 'Quiz',
          icon: Icons.quiz,
          variant: SwissButtonVariant.secondary,
          onPressed: () => context.push(AppRoutes.quizzes),
        ),
        SwissButton(
          label: 'Podcast',
          icon: Icons.mic,
          variant: SwissButtonVariant.secondary,
          onPressed: () => context.go(AppRoutes.audio),
        ),
      ],
    );
  }
}

/// Upcoming exams — Swiss cards.
class _UpcomingExams extends ConsumerWidget {
  const _UpcomingExams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final examsAsync = ref.watch(examsProvider);

    return examsAsync.when(
      loading: () => const SwissProcessingState(label: 'Loading exams'),
      error: (e, _) => SwissErrorState(
        title: 'Exams',
        message: 'Could not load your exams.',
        onRetry: () => ref.invalidate(examsProvider),
      ),
      data: (exams) {
        if (exams.isEmpty) {
          return SwissCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NO UPCOMING EXAMS',
                  style: SwissTypography.subheading.copyWith(color: fg),
                ),
                const SizedBox(height: SwissSpacing.xs),
                Text(
                  'Exams from your study setup appear here.',
                  style: SwissTypography.body.copyWith(color: mutedFg),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final exam in exams)
              SwissCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title.toUpperCase(),
                      style: SwissTypography.subheading.copyWith(color: fg),
                    ),
                    const SizedBox(height: SwissSpacing.xs),
                    Text(
                      '${exam.daysUntil(DateTime.now())} DAYS REMAINING',
                      style: SwissTypography.body.copyWith(color: mutedFg),
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
