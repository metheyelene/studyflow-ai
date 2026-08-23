import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../../shared/widgets/exam_countdown_card.dart';
import '../dashboard/dashboard_controller.dart';
import 'study_planner.dart';
import 'today_plan_section.dart';

/// Study tab — exam countdowns and the study-material entry point.
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  RouteInformationProvider? _routeInfo;
  bool _wasVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_routeInfo != router.routeInformationProvider) {
      _routeInfo?.removeListener(_onRouteChanged);
      _routeInfo = router.routeInformationProvider;
      _routeInfo!.addListener(_onRouteChanged);
      _onRouteChanged();
    }
  }

  @override
  void dispose() {
    _routeInfo?.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final loc = _routeInfo?.value.uri.path ?? '';
    final visible =
        loc == AppRoutes.study || loc.startsWith(AppRoutes.studyPlans);
    if (visible && !_wasVisible) {
      final current = ref.read(studyPlannerControllerProvider);
      if (current is AsyncData || current is AsyncError) {
        ref.read(studyPlannerControllerProvider.notifier).refreshSilently();
      }
    }
    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          SwissSpacing.xl,
          20,
          context.isPhone ? 120 : 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 01. STUDY
                const SwissSectionLabel(number: '01', title: 'STUDY'),
                const SizedBox(height: SwissSpacing.sm),
                Text(
                  'YOUR EXAMS AND STUDY MATERIAL.',
                  style: SwissTypography.section.copyWith(color: fg),
                ),
                const SizedBox(height: SwissSpacing.xl),
                const SwissDivider(thickness: 2),
                const SizedBox(height: SwissSpacing.xl),

                // UPCOMING EXAMS
                Text(
                  'UPCOMING EXAMS',
                  style: SwissTypography.label.copyWith(
                    color: isDark
                        ? SwissColors.darkForeground.withValues(alpha: 0.5)
                        : SwissColors.black.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SwissSpacing.md),
                _ExamsSection(dashboard: dashboard),
                const SizedBox(height: SwissSpacing.xxl),

                const SwissDivider(thickness: 2),
                const SizedBox(height: SwissSpacing.xl),

                // TODAY'S PLAN
                Text(
                  "TODAY'S PLAN",
                  style: SwissTypography.label.copyWith(
                    color: isDark
                        ? SwissColors.darkForeground.withValues(alpha: 0.5)
                        : SwissColors.black.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SwissSpacing.md),
                TodayPlanSection(dashboard: dashboard),
                const SizedBox(height: SwissSpacing.xxl),

                const SwissDivider(thickness: 2),
                const SizedBox(height: SwissSpacing.xl),

                // STUDY MATERIAL
                Text(
                  'STUDY MATERIAL',
                  style: SwissTypography.label.copyWith(
                    color: isDark
                        ? SwissColors.darkForeground.withValues(alpha: 0.5)
                        : SwissColors.black.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SwissSpacing.md),
                SwissCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TURN NOTES INTO STUDY TOOLS',
                        style: SwissTypography.subheading.copyWith(color: fg),
                      ),
                      const SizedBox(height: SwissSpacing.xs),
                      Text(
                        'Open a notebook, paste your notes, and StudyFlow AI will '
                        'answer questions, make flashcards and quizzes, and build '
                        'study guides from that material.',
                        style: SwissTypography.body.copyWith(
                          color: isDark
                              ? SwissColors.darkForeground.withValues(
                                  alpha: 0.6,
                                )
                              : SwissColors.black.withValues(alpha: 0.6),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: SwissSpacing.lg),
                      SwissButton(
                        label: 'Open notebooks',
                        icon: Icons.library_books,
                        onPressed: () => context.go(AppRoutes.notebooks),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamsSection extends ConsumerWidget {
  const _ExamsSection({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return dashboard.when(
      loading: () => SwissCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 180,
              height: 15,
              color: isDark ? SwissColors.darkMuted : SwissColors.muted,
            ),
            const SizedBox(height: SwissSpacing.sm),
            Container(
              width: 260,
              height: 12,
              color: isDark ? SwissColors.darkMuted : SwissColors.muted,
            ),
          ],
        ),
      ),
      error: (_, _) => SwissCard(
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 22, color: mutedFg),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Text(
                'Could not load your exams.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
            ),
            SwissButton(
              label: 'Retry',
              variant: SwissButtonVariant.ghost,
              compact: true,
              onPressed: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
      data: (snapshot) {
        if (snapshot.exams.isEmpty) {
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
                  'Exams from your study setup appear here with a countdown.',
                  style: SwissTypography.body.copyWith(color: mutedFg),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final exam in snapshot.exams) ...[
              ExamCountdownCard(exam: exam),
              const SizedBox(height: SwissSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}
