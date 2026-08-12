import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.popOrHome(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Study plan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
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
    final g = context.glass;

    // Group tasks by date, keeping plan order.
    final dates = <String>[];
    for (final t in plan.tasks) {
      if (!dates.contains(t.date)) dates.add(t.date);
    }
    final today = _dateKey(DateTime.now().toUtc());

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 32),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.examTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'v${plan.version}',
                        style: TextStyle(
                          color: g.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.doneCount} of ${plan.tasks.length} tasks done',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
                    minHeight: 6,
                    backgroundColor: g.surfaceSubtle,
                    color: g.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Generated ${_dayLabel(plan.generatedForDate, today)}. Regenerating rebuilds from today and keeps completed tasks.',
                  style: AppText.small.copyWith(
                    color: g.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: Text(
              _dayLabel(date, today),
              style: AppText.eyebrow.copyWith(color: g.textMuted),
            ),
          ),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < plan.tasksOn(date).length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: g.textPrimary.withValues(alpha: 0.06),
                      height: 1,
                      indent: 48,
                    ),
                  _TaskTile(
                    task: plan.tasksOn(date)[i],
                    onToggle: () => onToggle(plan.tasksOn(date)[i]),
                    onSkip: () => onSkip(plan.tasksOn(date)[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        GlassButton(
          label: 'Regenerate plan',
          icon: Icons.refresh,
          variant: GlassButtonVariant.glass,
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
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          Checkbox(
            value: task.isDone,
            onChanged: (_) => onToggle(),
            activeColor: g.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: g.textMuted,
                  ),
                ),
                if (task.detail.isNotEmpty)
                  Text(
                    task.detail,
                    style: TextStyle(
                      color: g.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${task.durationMin} min',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: task.isSkipped ? g.textMuted : g.warning,
              textStyle: const TextStyle(fontSize: 12.5),
            ),
            child: Text(task.isSkipped ? 'Unskip' : 'Skip'),
          ),
        ],
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
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Try again',
                icon: Icons.refresh,
                variant: GlassButtonVariant.glass,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
