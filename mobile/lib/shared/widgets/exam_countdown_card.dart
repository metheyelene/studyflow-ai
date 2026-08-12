import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/dashboard_repository.dart';
import '../../features/study/study_planner.dart';
import 'glass/glass_card.dart';
import 'glass/glass_misc.dart';

/// Exam countdown card, shared by the dashboard (UPCOMING) and the Study
/// tab. Communicates urgency through hierarchy, not alarms.
///
/// The footer is fed by real plan data ([studyPlannerControllerProvider]):
/// when a study plan exists for the exam it shows plan progress and a
/// View Study Plan action; when the exam is still ahead and unplanned it
/// offers to build the plan. If the plan fetch is still loading a thin
/// skeleton keeps the card calm; if it failed, the countdown still stands
/// alone rather than showing an error inside every card.
class ExamCountdownCard extends ConsumerWidget {
  const ExamCountdownCard({super.key, required this.exam});

  final UpcomingExam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final days = exam.daysUntil(DateTime.now());
    final countdown = days < 0
        ? 'Date set'
        : days == 0
        ? 'Today'
        : '$days days';
    final soon = days >= 0 && days <= 7;
    final plans = ref.watch(studyPlannerControllerProvider);
    final plan = plans.valueOrNull
        ?.where((p) => p.examId == exam.id)
        .firstOrNull;

    return GlassCard(
      tone: soon ? GlassTone.floating : GlassTone.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: soon
                        ? g.amber.withValues(alpha: 0.18)
                        : g.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    size: 22,
                    color: soon ? g.amber : g.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exam.displayDate,
                        style: TextStyle(color: g.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  countdown,
                  style: TextStyle(
                    color: soon ? g.amber : g.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            _buildFooter(
              context,
              ref,
              g,
              plan: plan,
              plansLoading: plans.isLoading,
              days: days,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    GlassTheme g, {
    required StudyPlan? plan,
    required bool plansLoading,
    required int days,
  }) {
    // Plans still loading — a thin skeleton keeps the layout stable.
    if (plansLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            GlassSkeleton(height: 5, radius: 99),
            SizedBox(height: 8),
            GlassSkeleton(width: 140, height: 12),
          ],
        ),
      );
    }

    // A real plan exists — progress plus the way into the full plan.
    if (plan != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
              minHeight: 5,
              backgroundColor: g.surfaceSubtle,
              color: g.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plan.doneCount}/${plan.tasks.length} tasks · ${plan.progressPercent}%',
                  style: TextStyle(color: g.textMuted, fontSize: 12.5),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.push('${AppRoutes.studyPlans}/${plan.examId}'),
                style: TextButton.styleFrom(
                  foregroundColor: g.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Study Plan'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    // No plan yet and the exam is still ahead — offer to build one.
    // Past exams ("Date set") get no footer: there is nothing to schedule.
    if (days >= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(studyPlannerControllerProvider.notifier)
                  .generate(exam.id);
            } on StudyPlannerException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              }
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: g.primary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.event_note_outlined, size: 16),
          label: const Text('Build study plan'),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
