import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_repository.dart';
import 'study_planner.dart';

/// "Today's plan" — the adaptive daily plan for the nearest upcoming exam.
class TodayPlanSection extends ConsumerWidget {
  const TodayPlanSection({super.key, required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    final plans = ref.watch(studyPlannerControllerProvider);
    final exams = dashboard.valueOrNull?.exams ?? const <UpcomingExam>[];
    final todayKey = _dateKey(DateTime.now().toUtc());

    final now = DateTime.now();
    final nearest = exams.where((e) => e.daysUntil(now) >= 0).firstOrNull;

    if (nearest == null) {
      return SwissCard(
        child: Text(
          'SET AN EXAM DATE AND STUDYFLOW WILL BUILD AN ADAPTIVE DAILY PLAN.',
          style: SwissTypography.body.copyWith(color: mutedFg, height: 1.4),
        ),
      );
    }

    return plans.when(
      loading: () => SwissCard(
        child: Container(
          height: 120,
          color: isDark ? SwissColors.darkMuted : SwissColors.muted,
        ),
      ),
      error: (err, _) => SwissCard(
        child: Row(
          children: [
            Icon(Icons.error, size: 20, color: SwissColors.red),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Text(
                'COULD NOT LOAD YOUR STUDY PLAN.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
            ),
            SwissButton(
              label: 'Retry',
              variant: SwissButtonVariant.ghost,
              compact: true,
              onPressed: () =>
                  ref.read(studyPlannerControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
      data: (planList) {
        final plan =
            planList.where((p) => p.examId == nearest.id).firstOrNull;

        if (plan == null) {
          return SwissCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${nearest.title.toUpperCase()} — NO PLAN YET',
                  style: SwissTypography.subheading.copyWith(color: fg),
                ),
                const SizedBox(height: SwissSpacing.xs),
                Text(
                  'Generate a daily plan from today to your exam date.',
                  style: SwissTypography.body.copyWith(color: mutedFg),
                ),
                const SizedBox(height: SwissSpacing.md),
                SwissButton(
                  label: 'Plan this exam',
                  icon: Icons.event_note,
                  onPressed: () async {
                    await ref
                        .read(studyPlannerControllerProvider.notifier)
                        .generate(nearest.id);
                  },
                ),
              ],
            ),
          );
        }

        final todayTasks = plan.tasksOn(todayKey);
        final overdue = plan.tasks
            .where((t) => t.isPending && t.date.compareTo(todayKey) < 0)
            .toList();

        return SwissCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plan.examTitle.toUpperCase()} · V${plan.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwissTypography.subheading.copyWith(color: fg),
                    ),
                  ),
                  Text(
                    '${plan.doneCount}/${plan.tasks.length}',
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
              if (plan.focus != null) ...[
                const SizedBox(height: SwissSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(SwissSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: SwissColors.red,
                        width: SwissShapes.borderMedium,
                      ),
                    ),
                  ),
                  child: Text(
                    'FOCUSING ON ${plan.focus!.subjectName} — ${plan.focus!.accuracy}% ACCURACY',
                    style: SwissTypography.caption.copyWith(
                      color: SwissColors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SwissSpacing.md),
              SwissProgressBar(
                value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
                height: 6,
              ),
              const SizedBox(height: SwissSpacing.md),
              if (overdue.isNotEmpty) ...[
                Text(
                  '${overdue.length} OVERDUE TASK${overdue.length == 1 ? '' : 'S'}',
                  style: SwissTypography.caption.copyWith(color: SwissColors.red),
                ),
                const SizedBox(height: SwissSpacing.xs),
              ],
              if (todayTasks.isEmpty && overdue.isEmpty)
                Text(
                  'NOTHING SCHEDULED TODAY.',
                  style: SwissTypography.body.copyWith(color: mutedFg),
                )
              else
                for (final task in [...todayTasks, ...overdue]) ...[
                  _PlanTaskRow(
                    task: task,
                    onToggle: () => ref
                        .read(studyPlannerControllerProvider.notifier)
                        .updateTask(
                          plan,
                          task,
                          task.isDone ? 'pending' : 'done',
                        ),
                  ),
                  const SizedBox(height: SwissSpacing.xs),
                ],
              const SizedBox(height: SwissSpacing.sm),
              Wrap(
                spacing: SwissSpacing.sm,
                runSpacing: SwissSpacing.sm,
                children: [
                  SwissButton(
                    label: 'Full plan',
                    variant: SwissButtonVariant.ghost,
                    compact: true,
                    onPressed: () => context.push(
                      '${AppRoutes.studyPlans}/${plan.examId}',
                    ),
                  ),
                  SwissButton(
                    label: 'Regenerate',
                    variant: SwissButtonVariant.ghost,
                    compact: true,
                    onPressed: () => ref
                        .read(studyPlannerControllerProvider.notifier)
                        .generate(plan.examId),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _PlanTaskRow extends StatelessWidget {
  const _PlanTaskRow({required this.task, required this.onToggle});

  final StudyPlanTask task;
  final VoidCallback onToggle;

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
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: task.isDone ? fg : Colors.transparent,
                border: Border.all(
                  color: task.isDone ? fg : mutedFg,
                  width: 2,
                ),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 14, color: SwissColors.white)
                  : null,
            ),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.toUpperCase(),
                    style: SwissTypography.body.copyWith(
                      color: task.isDone ? mutedFg : fg,
                      fontSize: 13,
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: mutedFg,
                    ),
                  ),
                  if (task.detail.isNotEmpty)
                    Text(
                      task.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                ],
              ),
            ),
            Text(
              '${task.durationMin}m',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
          ],
        ),
      ),
    );
  }
}
