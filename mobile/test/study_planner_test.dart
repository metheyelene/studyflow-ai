import 'package:flutter/material.dart';
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

  StudyPlan seedPlan({int version = 1, bool todayDone = false}) {
    return StudyPlan(
      id: 'plan-ex-1',
      examId: 'ex-1',
      examTitle: 'Physics Midterm',
      version: version,
      generatedForDate: todayKey(),
      examDate: examDateIn(10),
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

    expect(find.text('Physics Midterm — no plan yet'), findsOneWidget);
    await tester.tap(find.text('Plan this exam'));
    await tester.pumpAndSettle();

    expect(planner.generateCalls, 1);
    expect(planner.lastGeneratedExamId, 'ex-1');
    expect(find.text('Review core concepts'), findsOneWidget);
    expect(find.text('0/1 done'), findsOneWidget);
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

    expect(find.text('Review core concepts'), findsOneWidget);
    // The overdue task from yesterday surfaces too.
    expect(find.textContaining('1 overdue task'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(
      planner.plans.single.tasks.firstWhere((t) => t.id == 't-today').status,
      'done',
    );
    expect(find.text('1/3 done'), findsOneWidget);
  });

  testWidgets('plan screen groups by date with version and regenerate', (
    tester,
  ) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan(version: 2)]);
    final router = buildAppRouter();
    await pumpApp(tester, router: router, planner: planner);
    router.go('/study/plans/ex-1');
    await tester.pumpAndSettle();

    expect(find.text('v2'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Practice problems'), findsOneWidget);

    await tester.ensureVisible(find.text('Regenerate plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regenerate plan'));
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

    // The dashboard's exam cards build the planner provider at startup
    // (initial fetch = 1 list call); the first Study visit then runs the
    // silent refresh so today's tasks are fetched fresh (2nd call).
    router.go('/study');
    await tester.pumpAndSettle();
    expect(planner.listCalls, 2);
    expect(find.text('Review core concepts'), findsOneWidget);

    // Leaving and returning must trigger a background refresh so the
    // backend's lazy regeneration reaches the UI on every visit.
    router.go('/home');
    await tester.pumpAndSettle();
    router.go('/study');
    await tester.pumpAndSettle();
    expect(planner.listCalls, 3);
    expect(find.text('Review core concepts'), findsOneWidget);
  });

  testWidgets('skipping a task marks it skipped in the plan', (tester) async {
    final planner = FakeStudyPlannerRepository(plans: [seedPlan()]);
    final router = buildAppRouter();
    await pumpApp(tester, router: router, planner: planner);
    router.go('/study/plans/ex-1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip').first);
    await tester.pumpAndSettle();
    expect(
      planner.plans.single.tasks.firstWhere((t) => t.id == 't-today').status,
      'skipped',
    );
    expect(find.text('Unskip'), findsOneWidget);
  });
}
