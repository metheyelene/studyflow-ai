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
  testWidgets('Study tab shows real exam countdowns and a real material CTA',
      (tester) async {
    final examDate = DateTime.now().add(const Duration(days: 6));
    await pumpApp(
      tester,
      dashboard: FakeDashboardRepository(
        currentExams: [
          UpcomingExam(id: 'ex-1', title: 'Organic Chemistry', date: _fmt(examDate)),
        ],
      ),
    );

    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();

    expect(find.text('Organic Chemistry'), findsOneWidget);
    expect(find.text('6 days'), findsOneWidget);
    expect(find.text('UPCOMING EXAMS'), findsOneWidget);

    // The material CTA navigates to a real screen — the notebooks tab.
    await tester.tap(find.text('Open notebooks'));
    await tester.pumpAndSettle();
    expect(find.text('Notebooks'), findsWidgets);
  });

  testWidgets('Progress tab shows live notebook and source counts', (tester) async {
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

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget); // notebooks
    expect(find.text('3'), findsOneWidget); // sources
    expect(find.text('5'), findsOneWidget); // AI actions used
    expect(find.text('AI actions'), findsOneWidget);
    expect(find.text('Your insights appear as you study'), findsOneWidget);

    // CTA goes somewhere real. The insights card sits below the new
    // flashcard-history section, so scroll it into view first.
    await tester.ensureVisible(find.text('Open notebooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open notebooks'));
    await tester.pumpAndSettle();
    expect(find.text('Cell Biology'), findsOneWidget);
  });
}
