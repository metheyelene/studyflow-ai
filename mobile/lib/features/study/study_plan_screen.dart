import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';

import '../../core/theme/responsive.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'study_planner.dart';

/// The full adaptive plan for one exam: date-grouped tasks with
/// done/skip controls, progress, and adaptive regeneration.
class StudyPlanScreen extends ConsumerWidget {
  const StudyPlanScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(studyPlannerControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.popOrHome(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const Expanded(
                  child: Text('STUDY PLAN', style: SwissTypography.subheading),
                ),
              ],
            ),
          ),
          const SwissDivider(thickness: 2),
          Expanded(
            child: plans.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, _) => _ErrorState(
                message: err is StudyPlannerException
                    ? err.message
                    : 'Could not load that plan.',
                onRetry: () =>
                    ref.read(studyPlannerControllerProvider.notifier).refresh(),
              ),
              data: (planList) {
                final plan = planList
                    .where((p) => p.examId == examId)
                    .firstOrNull;
                if (plan == null) {
                  return _ErrorState(
                    message: 'No plan yet for this exam.',
                    onRetry: () => ref
                        .read(studyPlannerControllerProvider.notifier)
                        .refresh(),
                  );
                }
                return _PlanBody(
                  plan: plan,
                  onToggle: (task) => ref
                      .read(studyPlannerControllerProvider.notifier)
                      .updateTask(plan, task, task.isDone ? 'pending' : 'done'),
                  onSkip: (task) => ref
                      .read(studyPlannerControllerProvider.notifier)
                      .updateTask(
                        plan,
                        task,
                        task.isSkipped ? 'pending' : 'skipped',
                      ),
                  onRegenerate: () async {
                    await ref
                        .read(studyPlannerControllerProvider.notifier)
                        .generate(plan.examId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.plan,
    required this.onToggle,
    required this.onSkip,
    required this.onRegenerate,
  });

  final StudyPlan plan;
  final void Function(StudyPlanTask task) onToggle;
  final void Function(StudyPlanTask task) onSkip;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    final dates = <String>[];
    for (final t in plan.tasks) {
      if (!dates.contains(t.date)) dates.add(t.date);
    }
    final today = _dateKey(DateTime.now().toUtc());

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 32),
      children: [
        // Plan header
        SwissCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.examTitle.toUpperCase(),
                      style: SwissTypography.subheading.copyWith(color: fg),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SwissSpacing.sm,
                      vertical: SwissSpacing.xxs,
                    ),
                    color: SwissColors.red,
                    child: Text(
                      'V${plan.version}',
                      style: SwissTypography.label.copyWith(
                        color: SwissColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwissSpacing.xs),
              Text(
                '${plan.doneCount} OF ${plan.tasks.length} TASKS DONE',
                style: SwissTypography.caption.copyWith(color: mutedFg),
              ),
              const SizedBox(height: SwissSpacing.md),
              SwissProgressBar(
                value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
                height: 6,
              ),
              const SizedBox(height: SwissSpacing.sm),
              Text(
                'Generated ${_dayLabel(plan.generatedForDate, today)}.',
                style: SwissTypography.caption.copyWith(color: mutedFg),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwissSpacing.lg),

        // Date groups
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SwissSpacing.xs),
            child: Text(
              _dayLabel(date, today).toUpperCase(),
              style: SwissTypography.label.copyWith(
                color: SwissColors.red,
                letterSpacing: 1.5,
              ),
            ),
          ),
          for (var i = 0; i < plan.tasksOn(date).length; i++) ...[
            if (i > 0) const SwissHairline(),
            _TaskTile(
              task: plan.tasksOn(date)[i],
              onToggle: () => onToggle(plan.tasksOn(date)[i]),
              onSkip: () => onSkip(plan.tasksOn(date)[i]),
            ),
          ],
          const SizedBox(height: SwissSpacing.md),
        ],

        const SwissDivider(thickness: 1),
        const SizedBox(height: SwissSpacing.md),
        SwissButton(
          label: 'Regenerate plan',
          icon: Icons.refresh,
          variant: SwissButtonVariant.secondary,
          onPressed: onRegenerate,
        ),
      ],
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _dayLabel(String date, String today) {
    if (date == today) return 'Today';
    final d = DateTime.tryParse('${date}T00:00:00Z');
    if (d == null) return date;
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    if (date == _dateKey(tomorrow)) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onSkip,
  });

  final StudyPlanTask task;
  final VoidCallback onToggle;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.sm),
        child: Row(
          children: [
            // Checkbox area
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isDone ? fg : Colors.transparent,
                border: Border.all(color: task.isDone ? fg : mutedFg, width: 2),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 16, color: SwissColors.white)
                  : null,
            ),
            const SizedBox(width: SwissSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.toUpperCase(),
                    style: SwissTypography.body.copyWith(
                      color: task.isDone ? mutedFg : fg,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: mutedFg,
                    ),
                  ),
                  if (task.detail.isNotEmpty) ...[
                    const SizedBox(height: SwissSpacing.xxs),
                    Text(
                      task.detail,
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${task.durationMin}m',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
            const SizedBox(width: SwissSpacing.sm),
            SwissButton(
              label: task.isSkipped ? 'Unskip' : 'Skip',
              variant: SwissButtonVariant.ghost,
              compact: true,
              onPressed: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SwissErrorState(
      title: message,
      message: 'Please try again.',
      onRetry: onRetry,
    );
  }
}
