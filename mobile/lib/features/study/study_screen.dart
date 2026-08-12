import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/exam_countdown_card.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../dashboard/dashboard_controller.dart';
import 'study_planner.dart';
import 'today_plan_section.dart';

/// Study tab — exam countdowns and the study-material entry point. Live
/// data only: exams come from the user's study setup; the material section
/// links to real notebooks.
///
/// The shell keeps tab bodies alive (StatefulShellRoute.indexedStack), so
/// the planner is silently re-fetched whenever this tab becomes visible —
/// the backend regenerates stale plans on read, which is what keeps
/// today's tasks current even if the plan was generated on an earlier day.
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
      // Skip while the provider is still running its first load — that
      // fetch already covers this visit and avoids a duplicate GET.
      if (current is AsyncData || current is AsyncError) {
        ref.read(studyPlannerControllerProvider.notifier).refreshSilently();
      }
    }
    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
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
                Text('Study', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Your exams and study material, in one place.',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'UPCOMING EXAMS'),
                const SizedBox(height: 10),
                _ExamsSection(dashboard: dashboard),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: "TODAY'S PLAN"),
                const SizedBox(height: 10),
                TodayPlanSection(dashboard: dashboard),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'STUDY MATERIAL'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turn notes into study tools',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open a notebook, paste your notes, and StudyFlow AI will '
                        'answer questions, make flashcards and quizzes, and build '
                        'study guides from that material.',
                        style: AppText.small.copyWith(
                          color: g.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassButton(
                        label: 'Open notebooks',
                        icon: Icons.library_books_outlined,
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
