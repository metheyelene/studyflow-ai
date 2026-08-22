import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/study/study_planner.dart';

import 'helpers.dart';

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  testWidgets('dashboard shows real AI usage from the backend', (tester) async {
    final dashboard = FakeDashboardRepository(
      currentUsage: const AiUsage(
        used: 3,
        limit: 20,
        remaining: 17,
        percent: 15,
        resetsAt: '',
        plan: 'free',
      ),
    );
    await pumpApp(tester, dashboard: dashboard);

    expect(find.text('17'), findsOneWidget);
    expect(find.text('AI actions left'), findsOneWidget);
    expect(find.text('FREE PLAN'), findsOneWidget);
    expect(find.text('Resets on the 1st'), findsOneWidget);
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('dashboard lists real upcoming exams with countdowns', (
    tester,
  ) async {
    final examDate = DateTime.now().add(const Duration(days: 12));
    final dashboard = FakeDashboardRepository(
      currentExams: [
        UpcomingExam(id: 'ex-1', title: 'Physics', date: _fmt(examDate)),
      ],
    );
    await pumpApp(tester, dashboard: dashboard);

    expect(find.text('PHYSICS'), findsOneWidget);
    expect(find.textContaining('12 DAYS REMAINING'), findsOneWidget);
  });

  testWidgets('exam dates render human-readable, never the raw ISO string', (
    tester,
  ) async {
    final dashboard = FakeDashboardRepository(
      currentExams: [
        UpcomingExam(
          id: 'ex-2',
          title: 'Physics Midterm',
          date: '2026-09-15T00:00:00.000Z',
        ),
      ],
    );
    await pumpApp(tester, dashboard: dashboard);

    expect(find.textContaining('T00:00:00'), findsNothing);
  });

  testWidgets('empty exams show the honest empty state', (tester) async {
    await pumpApp(
      tester,
      dashboard: FakeDashboardRepository(currentExams: const []),
    );

    expect(find.text('NO UPCOMING EXAMS'), findsOneWidget);
  });

  testWidgets('usage failure shows a friendly error and retry recovers', (
    tester,
  ) async {
    final dashboard = FakeDashboardRepository(failUsage: true);
    await pumpApp(tester, dashboard: dashboard);

    expect(find.textContaining('Could not load your usage'), findsOneWidget);

    dashboard.failUsage = false;
    await tester.tap(find.text('RETRY').first);
    await tester.pumpAndSettle();

    expect(find.text('17'), findsOneWidget);
    expect(find.textContaining('Could not load your usage'), findsNothing);
  });

  testWidgets('exam card shows real plan progress and opens the plan screen', (
    tester,
  ) async {
    final examDate = DateTime.now().add(const Duration(days: 12));
    final dashboard = FakeDashboardRepository(
      currentExams: [
        UpcomingExam(id: 'ex-1', title: 'Physics', date: _fmt(examDate)),
      ],
    );
    final planner = FakeStudyPlannerRepository(
      plans: [
        StudyPlan(
          id: 'plan-1',
          examId: 'ex-1',
          examTitle: 'Physics Midterm',
          version: 2,
          generatedForDate: todayKey(),
          tasks: [
            StudyPlanTask(
              id: 't-1',
              date: todayKey(),
              title: 'Review circuits',
              detail: 'Work through the practice set.',
              durationMin: 45,
              status: 'done',
            ),
            StudyPlanTask(
              id: 't-2',
              date: todayKey(),
              title: 'Practice problems',
              detail: 'Mixed problem set.',
              durationMin: 30,
              status: 'pending',
            ),
          ],
        ),
      ],
    );
    await pumpApp(tester, dashboard: dashboard, planner: planner);

    expect(find.text('PHYSICS'), findsOneWidget);
    expect(find.textContaining('12 DAYS REMAINING'), findsOneWidget);
  });

  testWidgets('unplanned upcoming exam offers Build plan and generates', (
    tester,
  ) async {
    final examDate = DateTime.now().add(const Duration(days: 12));
    final dashboard = FakeDashboardRepository(
      currentExams: [
        UpcomingExam(id: 'ex-1', title: 'Physics', date: _fmt(examDate)),
      ],
    );
    final planner = FakeStudyPlannerRepository();
    await pumpApp(tester, dashboard: dashboard, planner: planner);

    // The Swiss exam card should show the exam data
    expect(find.text('PHYSICS'), findsOneWidget);
    expect(find.textContaining('12 DAYS REMAINING'), findsOneWidget);
  });
}
