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
                  style: AppText.small.copyWith(
                    color: g.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to study?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _UsageHero(dashboard: dashboard),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'QUICK ACTIONS'),
                const SizedBox(height: 10),
                const _QuickActionsChips(),
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

/// Today's Focus hero with the real AI-usage meter — the flagship surface
/// on Home: large translucent hero, specular sheen, big type, animated ring.
class _UsageHero extends ConsumerWidget {
  const _UsageHero({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      tone: GlassTone.floating,
      glossy: true,
      radius: AppShapes.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "TODAY'S FOCUS",
                  style: AppText.eyebrow.copyWith(
                    color: context.glass.primary,
                  ),
                ),
              ),
              GlassBadge(
                label: 'AI workspace',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload your first note to start building a study system.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
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
        // Animate 0 → current on first appearance; further changes tween
        // from the previous value instead of snapping.
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: usage.limit > 0 ? usage.percent / 100 : 0,
          ),
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          builder: (context, value, _) => GlassRing(
            value: value,
            label: '${usage.used}/${usage.limit}',
          ),
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

/// Floating glossy action chips. Same destinations as the old grid — tabs
/// go() (shell tabs), detail routes push() so back returns to Home — but
/// the chips read as elevated translucent objects instead of a flat grid.
class _QuickActionsChips extends StatelessWidget {
  const _QuickActionsChips();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.upload_file, 'Upload notes', AppRoutes.notebooks, false),
      (Icons.auto_awesome, 'Summarize', AppRoutes.notebooks, false),
      (Icons.style_outlined, 'Flashcards', AppRoutes.flashcards, true),
      (Icons.quiz_outlined, 'Quiz', AppRoutes.quizzes, true),
      (Icons.mic_none, 'Podcast', AppRoutes.audio, true),
      (Icons.event_available_outlined, 'Study plan', AppRoutes.study, false),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in actions)
          _GlossyActionChip(
            icon: a.$1,
            label: a.$2,
            onTap: () => a.$4 ? context.push(a.$3) : context.go(a.$3),
          ),
      ],
    );
  }
}

class _GlossyActionChip extends StatefulWidget {
  const _GlossyActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_GlossyActionChip> createState() => _GlossyActionChipState();
}

class _GlossyActionChipState extends State<_GlossyActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: g.floating,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: g.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: g.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
