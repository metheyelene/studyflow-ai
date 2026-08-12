import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_repository.dart';
import 'study_planner.dart';

/// "Today's plan" — the adaptive daily plan for the nearest upcoming exam.
/// Tasks come from the backend plan (real data, checkable), with an
/// honest empty state and a link to the full plan screen.
class TodayPlanSection extends ConsumerWidget {
  const TodayPlanSection({super.key, required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final plans = ref.watch(studyPlannerControllerProvider);
    final exams = dashboard.valueOrNull?.exams ?? const <UpcomingExam>[];
    final todayKey = _dateKey(DateTime.now().toUtc());

    final now = DateTime.now();
    final nearest = exams.where((e) => e.daysUntil(now) >= 0).firstOrNull;

    if (nearest == null) {
      return GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 22,
                color: g.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set an exam date and StudyFlow will build an adaptive daily plan toward it.',
                  style: AppText.small.copyWith(
                    color: g.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return plans.when(
      loading: () => const GlassSkeleton(height: 130, radius: 20),
      error: (err, _) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: g.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Could not load your study plan.',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(studyPlannerControllerProvider.notifier).refresh(),
                style: TextButton.styleFrom(foregroundColor: g.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (planList) {
        final plan = planList.where((p) => p.examId == nearest.id).firstOrNull;

        if (plan == null) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${nearest.title} — no plan yet',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate a daily plan from today to your exam date. It adapts as the date approaches.',
                    style: AppText.small.copyWith(
                      color: g.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    label: 'Plan this exam',
                    icon: Icons.event_note_outlined,
                    onPressed: () async {
                      await ref
                          .read(studyPlannerControllerProvider.notifier)
                          .generate(nearest.id);
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final todayTasks = plan.tasksOn(todayKey);
        final overdue = plan.tasks
            .where((t) => t.isPending && t.date.compareTo(todayKey) < 0)
            .toList();

        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plan.examTitle} · v${plan.version}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${plan.doneCount}/${plan.tasks.length} done',
                      style: AppText.small.copyWith(color: g.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
                    minHeight: 5,
                    backgroundColor: g.surfaceSubtle,
                    color: g.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (overdue.isNotEmpty) ...[
                  Text(
                    '${overdue.length} overdue task${overdue.length == 1 ? '' : 's'} from earlier days',
                    style: TextStyle(color: g.warning, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                ],
                if (todayTasks.isEmpty && overdue.isEmpty)
                  Text(
                    'Nothing scheduled today — take a lighter day or regenerate for a new plan.',
                    style: AppText.small.copyWith(
                      color: g.textMuted,
                      height: 1.4,
                    ),
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
                    const SizedBox(height: 6),
                  ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GlassButton(
                      label: 'Full plan',
                      icon: Icons.view_list_outlined,
                      variant: GlassButtonVariant.glass,
                      size: GlassButtonSize.small,
                      onPressed: () => context.push(
                        '${AppRoutes.studyPlans}/${plan.examId}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(studyPlannerControllerProvider.notifier)
                          .generate(plan.examId),
                      style: TextButton.styleFrom(foregroundColor: g.primary),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Regenerate'),
                    ),
                  ],
                ),
              ],
            ),
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
    final g = context.glass;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: task.isDone,
              onChanged: (_) => onToggle(),
              activeColor: g.primary,
              visualDensity: VisualDensity.compact,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: g.textMuted,
                    ),
                  ),
                  if (task.detail.isNotEmpty)
                    Text(
                      task.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${task.durationMin}m',
              style: AppText.small.copyWith(color: g.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
