import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/study/study_planner.dart';

import 'helpers.dart';

void main() {
  String dayFromToday(int offset) {
    final d = DateTime.now().toUtc().add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String examDateIn(int days) => dayFromToday(days);

  final exams = [
    UpcomingExam(id: 'ex-1', title: 'Physics Midterm', date: examDateIn(10)),
  ];

  StudyPlan seedPlan({
    int version = 1,
    bool todayDone = false,
    StudyPlanFocus? focus,
  }) {
    return StudyPlan(
      id: 'plan-ex-1',
      examId: 'ex-1',
      examTitle: 'Physics Midterm',
      version: version,
      generatedForDate: todayKey(),
      examDate: examDateIn(10),
      focus: focus,
      tasks: [
        StudyPlanTask(
          id: 't-today',
          date: todayKey(),
          title: 'Review core concepts',
          detail: 'Work through your notes.',
          durationMin: 45,
          status: todayDone ? 'done' : 'pending',
        ),
        StudyPlanTask(
          id: 't-overdue',
          date: dayFromToday(-1),
          title: 'Practice problems',
          detail: 'Solve problems from your material.',
          durationMin: 40,
          status: 'pending',
        ),
        StudyPlanTask(
          id: 't-tomorrow',
          date: dayFromToday(1),
          title: 'Quiz yourself',
          detail: 'Take a quiz from this unit.',
          durationMin: 30,
          status: 'pending',
        ),
      ],
    );
  }

  testWidgets('generates a plan from the Study tab when none exists', (
    tester,
  ) async {
    final planner = FakeStudyPlannerRepository();
    final dashboard = FakeDashboardRepository(currentExams: exams);
    final router = buildAppRouter();
    await pumpApp(
      tester,
      router: router,
      planner: planner,
      dashboard: dashboard,
    );
    router.go('/study');
    await tester.pumpAndSettle();

    expect(find.text('PHYSICS MIDTERM — NO PLAN YET'), findsOneWidget);
    await tester.tap(find.text('PLAN THIS EXAM'));
    await tester.pumpAndSettle();

    expect(planner.generateCalls, 1);
    expect(planner.lastGeneratedExamId, 'ex-1');
    expect(find.text('REVIEW CORE CONCEPTS'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('checking a today task records it as done', (tester) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan()]);
    final dashboard = FakeDashboardRepository(currentExams: exams);
    final router = buildAppRouter();
    await pumpApp(
      tester,
      router: router,
      planner: planner,
      dashboard: dashboard,
    );
    router.go('/study');
    await tester.pumpAndSettle();

    expect(find.text('REVIEW CORE CONCEPTS'), findsOneWidget);
    // The overdue task from yesterday surfaces too.
    expect(find.textContaining('1 OVERDUE TASK'), findsOneWidget);

    await tester.tap(find.text('REVIEW CORE CONCEPTS'));
    await tester.pumpAndSettle();

    expect(
      planner.plans.single.tasks.firstWhere((t) => t.id == 't-today').status,
      'done',
    );
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('plan screen groups by date with version and regenerate', (
    tester,
  ) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan(version: 2)]);
    final router = buildAppRouter();
    await pumpApp(tester, router: router, planner: planner);
    router.go('/study/plans/ex-1');
    await tester.pumpAndSettle();

    expect(find.text('V2'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('PRACTICE PROBLEMS'), findsOneWidget);

    await tester.ensureVisible(find.text('REGENERATE PLAN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REGENERATE PLAN'));
    await tester.pumpAndSettle();
    expect(planner.generateCalls, 1);
    expect(planner.lastGeneratedExamId, 'ex-1');
  });

  testWidgets('revisiting the Study tab silently re-fetches the plan', (
    tester,
  ) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan()]);
    final dashboard = FakeDashboardRepository(currentExams: exams);
    final router = buildAppRouter();
    await pumpApp(
      tester,
      router: router,
      planner: planner,
      dashboard: dashboard,
    );

    // The first Study visit triggers the planner load.
    router.go('/study');
    await tester.pumpAndSettle();
    expect(planner.listCalls, greaterThanOrEqualTo(1));
    expect(find.text('REVIEW CORE CONCEPTS'), findsOneWidget);

    // Leaving and returning must trigger a background refresh so the
    // backend's lazy regeneration reaches the UI on every visit.
    router.go('/home');
    await tester.pumpAndSettle();
    router.go('/study');
    await tester.pumpAndSettle();
    expect(planner.listCalls, greaterThanOrEqualTo(2));
    expect(find.text('REVIEW CORE CONCEPTS'), findsOneWidget);
  });

  testWidgets('shows the weak-subject focus banner on a weighted plan', (
    tester,
  ) async {
    final planner = FakeStudyPlannerRepository(
      plans: [
        seedPlan(
          focus: const StudyPlanFocus(
            subjectId: 's-1',
            subjectName: 'Physics',
            accuracy: 55,
          ),
        ),
      ],
    );
    final dashboard = FakeDashboardRepository(currentExams: exams);
    final router = buildAppRouter();
    await pumpApp(
      tester,
      router: router,
      planner: planner,
      dashboard: dashboard,
    );
    router.go('/study');
    await tester.pumpAndSettle();

    expect(find.textContaining('FOCUSING ON PHYSICS'), findsOneWidget);
    expect(find.textContaining('FOCUSING ON PHYSICS — 55% ACCURACY'), findsOneWidget);
  });

  testWidgets('generic plans show no focus banner', (tester) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan()]);
    final dashboard = FakeDashboardRepository(currentExams: exams);
    final router = buildAppRouter();
    await pumpApp(
      tester,
      router: router,
      planner: planner,
      dashboard: dashboard,
    );
    router.go('/study');
    await tester.pumpAndSettle();

    expect(find.textContaining('Focusing on'), findsNothing);
  });

  testWidgets('skipping a task marks it skipped in the plan', (tester) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan()]);
    final router = buildAppRouter();
    await pumpApp(tester, router: router, planner: planner);
    router.go('/study/plans/ex-1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SKIP').first);
    await tester.pumpAndSettle();
    expect(
      planner.plans.single.tasks.firstWhere((t) => t.id == 't-today').status,
      'skipped',
    );
    expect(find.text('UNSKIP'), findsOneWidget);
  });
}
