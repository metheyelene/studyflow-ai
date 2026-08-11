import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';

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

    expect(find.text('3/20'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('17 left · resets on the 1st'), findsOneWidget);
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('dashboard lists real upcoming exams with countdowns', (tester) async {
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

  testWidgets('empty exams show the honest empty state', (tester) async {
    await pumpApp(tester, dashboard: FakeDashboardRepository(currentExams: const []));

    expect(find.text('No upcoming exams'), findsOneWidget);
  });

  testWidgets('usage failure shows a friendly error and retry recovers', (tester) async {
    final dashboard = FakeDashboardRepository(failUsage: true);
    await pumpApp(tester, dashboard: dashboard);

    expect(find.text('Could not load your usage.'), findsOneWidget);

    dashboard.failUsage = false;
    // Both the usage meter and the exams section show a retry — use the
    // first (the usage hero's).
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();

    expect(find.text('3/20'), findsOneWidget);
    expect(find.text('Could not load your usage.'), findsNothing);
  });
}
