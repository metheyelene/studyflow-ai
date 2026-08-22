import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../features/dashboard/dashboard_repository.dart';
import '../../features/study/study_planner.dart';
import 'swiss/swiss_components.dart';

/// Exam countdown card, shared by the dashboard and Study tab.
class ExamCountdownCard extends ConsumerWidget {
  const ExamCountdownCard({super.key, required this.exam});

  final UpcomingExam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    final days = exam.daysUntil(DateTime.now());
    final countdown = days < 0
        ? 'DATE SET'
        : days == 0
        ? 'TODAY'
        : '$days DAYS';
    final soon = days >= 0 && days <= 7;
    final plans = ref.watch(studyPlannerControllerProvider);
    final plan = plans.valueOrNull
        ?.where((p) => p.examId == exam.id)
        .firstOrNull;

    return SwissCard(
      padding: const EdgeInsets.all(SwissSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Numbered indicator
              Container(
                width: 44,
                height: 44,
                color: soon ? SwissColors.red : fg,
                alignment: Alignment.center,
                child: Text(
                  days < 0 ? '—' : '$days',
                  style: SwissTypography.subheading.copyWith(
                    color: SwissColors.white,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: SwissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwissTypography.subheading.copyWith(
                        color: fg,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: SwissSpacing.xxs),
                    Text(
                      exam.displayDate,
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                  ],
                ),
              ),
              Text(
                countdown,
                style: SwissTypography.label.copyWith(
                  color: soon ? SwissColors.red : fg,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          _buildFooter(
            context,
            ref,
            isDark: isDark,
            fg: fg,
            mutedFg: mutedFg,
            plan: plan,
            plansLoading: plans.isLoading,
            days: days,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required Color fg,
    required Color mutedFg,
    required StudyPlan? plan,
    required bool plansLoading,
    required int days,
  }) {
    if (plansLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: SwissSpacing.md),
        child: SwissProgressBar(value: 0, height: 4),
      );
    }

    if (plan != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: SwissSpacing.md),
          SwissProgressBar(
            value: plan.tasks.isEmpty ? 0 : plan.progressPercent / 100,
            height: 4,
          ),
          const SizedBox(height: SwissSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plan.doneCount}/${plan.tasks.length} TASKS · ${plan.progressPercent}%',
                  style: SwissTypography.caption.copyWith(color: mutedFg),
                ),
              ),
              SwissButton(
                label: 'View plan',
                variant: SwissButtonVariant.ghost,
                compact: true,
                onPressed: () =>
                    context.push('${AppRoutes.studyPlans}/${plan.examId}'),
              ),
            ],
          ),
        ],
      );
    }

    if (days >= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: SwissSpacing.xs),
        child: SwissButton(
          label: 'Build study plan',
          icon: Icons.event_note,
          variant: SwissButtonVariant.ghost,
          compact: true,
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
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
