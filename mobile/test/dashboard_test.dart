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

    // The editorial hero leads with the remaining-actions numeral.
    expect(find.text('17'), findsOneWidget);
    expect(find.text('AI actions left'), findsOneWidget);
    expect(find.text('Free plan · resets on the 1st'), findsOneWidget);
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

    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('12 days'), findsOneWidget);
  });

  testWidgets('exam dates render human-readable, never the raw ISO string', (
    tester,
  ) async {
    // The API sends full ISO timestamps (e.g. 2026-09-15T00:00:00.000Z).
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
    expect(find.text('Sep 15, 2026'), findsOneWidget);
  });

  testWidgets('empty exams show the honest empty state', (tester) async {
    await pumpApp(
      tester,
      dashboard: FakeDashboardRepository(currentExams: const []),
    );

    expect(find.text('No upcoming exams'), findsOneWidget);
  });

  testWidgets('usage failure shows a friendly error and retry recovers', (
    tester,
  ) async {
    final dashboard = FakeDashboardRepository(failUsage: true);
    await pumpApp(tester, dashboard: dashboard);

    expect(find.text('Could not load your usage.'), findsOneWidget);

    dashboard.failUsage = false;
    // Both the usage meter and the exams section show a retry — use the
    // first (the usage hero's).
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();

    expect(find.text('17'), findsOneWidget);
    expect(find.text('Could not load your usage.'), findsNothing);
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

    // Countdown plus the real plan summary (1 of 2 tasks done).
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('12 days'), findsOneWidget);
    expect(find.text('1/2 tasks · 50%'), findsOneWidget);
    expect(find.text('View Study Plan'), findsOneWidget);

    // The action opens the full plan screen for this exam.
    await tester.ensureVisible(find.text('View Study Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Study Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Physics Midterm'), findsWidgets);
    expect(find.text('Review circuits'), findsOneWidget);
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

    expect(find.text('Build study plan'), findsOneWidget);
    expect(find.text('View Study Plan'), findsNothing);

    await tester.ensureVisible(find.text('Build study plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build study plan'));
    await tester.pumpAndSettle();

    // The fake generated a real plan for this exam and the card switched
    // to the plan footer.
    expect(planner.generateCalls, 1);
    expect(planner.lastGeneratedExamId, 'ex-1');
    expect(find.text('View Study Plan'), findsOneWidget);
    expect(find.text('Build study plan'), findsNothing);
  });
}
