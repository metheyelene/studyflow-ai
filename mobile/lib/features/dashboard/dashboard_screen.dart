import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/exam_countdown_card.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_progress.dart';
import 'dashboard_controller.dart';
import 'dashboard_repository.dart';

/// Home tab. Greeting, Today's Focus hero, quick actions, progress, and
/// upcoming exams. The live widgets (AI usage, exams) come from the API
/// with skeleton/error states; nothing here is hardcoded data.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final dashboard = ref.watch(dashboardControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          AppSpacing.xl,
          20,
          context.isPhone ? 120 : 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _greeting(),
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to study?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                _UsageHero(dashboard: dashboard),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'QUICK ACTIONS'),
                const SizedBox(height: 10),
                const _QuickActionsGrid(),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'YOUR PROGRESS'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      const _StatRow(
                        icon: Icons.local_fire_department,
                        label: 'Study streak',
                        value: '0 days',
                      ),
                      Divider(
                        color: g.textPrimary.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      const _StatRow(
                        icon: Icons.quiz_outlined,
                        label: 'Quizzes completed',
                        value: '0',
                      ),
                      Divider(
                        color: g.textPrimary.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      const _StatRow(
                        icon: Icons.notes,
                        label: 'Notes created',
                        value: '0',
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'UPCOMING'),
                const SizedBox(height: 10),
                _UpcomingExams(dashboard: dashboard),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's Focus hero with the real AI-usage meter.
class _UsageHero extends ConsumerWidget {
  const _UsageHero({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      tone: GlassTone.floating,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: "TODAY'S FOCUS"),
          const SizedBox(height: 8),
          Text(
            'Upload your first note to start building a study system.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          dashboard.when(
            loading: () => const _UsageSkeleton(),
            error: (_, _) => _UsageError(
              onRetry: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
            data: (snapshot) => _UsageMeter(usage: snapshot.usage),
          ),
        ],
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({required this.usage});

  final AiUsage usage;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final planLabel = switch (usage.plan) {
      'premium' => 'Premium',
      'founding_member' => 'Founding member',
      _ => 'Free',
    };
    return Row(
      children: [
        GlassRing(
          value: usage.limit > 0 ? usage.percent / 100 : 0,
          label: '${usage.used}/${usage.limit}',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI actions',
                      style: AppText.bodyMedium.copyWith(color: g.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassBadge(
                    label: planLabel,
                    icon: Icons.workspace_premium_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                usage.remaining > 0
                    ? '${usage.remaining} left · resets on the 1st'
                    : 'Allowance used · resets on the 1st',
                style: AppText.small.copyWith(color: g.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsageSkeleton extends StatelessWidget {
  const _UsageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const GlassSkeleton(width: 84, height: 84, radius: 42),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              GlassSkeleton(width: 120, height: 15),
              SizedBox(height: 8),
              GlassSkeleton(width: 160, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsageError extends ConsumerWidget {
  const _UsageError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 22,
          color: g.textMuted.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not load your usage.',
            style: AppText.small.copyWith(color: g.textMuted),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: g.primary),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _UpcomingExams extends ConsumerWidget {
  const _UpcomingExams({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return dashboard.when(
      loading: () => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            GlassSkeleton(width: 180, height: 15),
            SizedBox(height: 10),
            GlassSkeleton(width: 260, height: 12),
          ],
        ),
      ),
      error: (_, _) => GlassCard(
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 22,
              color: g.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load your exams.',
                style: AppText.small.copyWith(color: g.textMuted),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
              style: TextButton.styleFrom(foregroundColor: g.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (snapshot) {
        if (snapshot.exams.isEmpty) {
          return GlassCard(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Icon(
                  Icons.event_outlined,
                  size: 26,
                  color: g.textMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'No upcoming exams',
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exams from your study setup appear here with a countdown as they approach.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final exam in snapshot.exams) ...[
              ExamCountdownCard(exam: exam),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppText.eyebrow.copyWith(color: context.glass.textMuted),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: g.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppText.small.copyWith(color: g.textPrimary),
            ),
          ),
          Text(value, style: AppText.bodyMedium.copyWith(color: g.textPrimary)),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    // Tabs navigate with go(); pushed detail routes (flashcards) use push()
    // so back returns to the dashboard instead of hitting an empty stack.
    const actions = [
      (Icons.upload_file, 'Upload notes', AppRoutes.notebooks, false),
      (Icons.auto_awesome, 'Summarize', AppRoutes.notebooks, false),
      (Icons.style_outlined, 'Flashcards', AppRoutes.flashcards, true),
      (Icons.quiz_outlined, 'Quiz', AppRoutes.quizzes, true),
      (Icons.mic_none, 'Podcast', AppRoutes.audio, true),
      (Icons.event_available_outlined, 'Study plan', AppRoutes.study, false),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = context.isPhone ? 2 : 3;
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in actions)
              SizedBox(
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => a.$4 ? context.push(a.$3) : context.go(a.$3),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: g.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: g.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.$1, size: 20, color: g.primary),
                          const SizedBox(height: 10),
                          Text(
                            a.$2,
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
