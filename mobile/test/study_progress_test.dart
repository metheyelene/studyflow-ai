import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';

import 'helpers.dart';

const _progressUsage = AiUsage(
  used: 5,
  limit: 20,
  remaining: 15,
  percent: 25,
  resetsAt: '',
  plan: 'free',
);

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  testWidgets('Study tab shows real exam countdowns and a real material CTA', (
    tester,
  ) async {
    final examDate = DateTime.now().add(const Duration(days: 6));
    await pumpApp(
      tester,
      dashboard: FakeDashboardRepository(
        currentExams: [
          UpcomingExam(
            id: 'ex-1',
            title: 'Organic Chemistry',
            date: _fmt(examDate),
          ),
        ],
      ),
    );

    await tester.tap(find.text('STUDY'));
    await tester.pumpAndSettle();

    expect(find.text('ORGANIC CHEMISTRY'), findsOneWidget);
    expect(find.text('6 DAYS'), findsOneWidget);
    expect(find.text('UPCOMING EXAMS'), findsOneWidget);

    // The material CTA navigates to a real screen — the notebooks tab.
    await tester.tap(find.text('Open notebooks'));
    await tester.pumpAndSettle();
    expect(find.text('NOTEBOOKS'), findsWidgets);
  });

  testWidgets('Progress tab asks the question and demotes raw counts', (
    tester,
  ) async {
    final notebooks = FakeNotebooksRepository();
    notebooks.notebooks.addAll([
      Notebook(
        id: 'nb-1',
        title: 'Cell Biology',
        sourceCount: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      Notebook(
        id: 'nb-2',
        title: 'VLSI',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    await pumpApp(
      tester,
      notebooks: notebooks,
      dashboard: FakeDashboardRepository(currentUsage: _progressUsage),
    );

    await tester.tap(find.text('PROGRESS'));
    await tester.pumpAndSettle();

    // One question, honest empty mastery, and the counts demoted to a
    // single quiet metadata line instead of a three-stat-card wall.
    expect(find.text('HOW AM I DOING?'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // no reviews yet
    expect(find.text('2 notebooks · 3 sources · 5 AI actions'), findsOneWidget);
    expect(find.text('AI actions'), findsNothing); // no stat card label

    // The single recommended action goes somewhere real.
    await tester.tap(find.text('Review flashcards'));
    await tester.pumpAndSettle();
    expect(find.text('No decks yet'), findsOneWidget);
  });
}
