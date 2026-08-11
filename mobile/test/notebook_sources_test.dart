import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';

import 'helpers.dart';

Future<void> openNotebookSourcesTab(WidgetTester tester) async {
  await tester.tap(find.text('Notebooks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cell Biology'));
  await tester.pumpAndSettle();
}

void main() {
  Future<FakeNotebooksRepository> pumpWithNotebook(WidgetTester tester) async {
    final fake = FakeNotebooksRepository();
    fake.notebooks.add(Notebook(
      id: 'nb-1',
      title: 'Cell Biology',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
    await pumpApp(tester, notebooks: fake);
    return fake;
  }

  testWidgets('Sources tab shows a real empty state with a Paste text action',
      (tester) async {
    await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.text('Paste text'), findsOneWidget);
  });

  testWidgets('pasting a source adds it to the list for real', (tester) async {
    final fake = await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();

    // Sheet: title + text.
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Lecture 4 — Photosynthesis');
    await tester.enterText(fields.at(1), 'Photosynthesis converts light energy into chemical energy.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();

    expect(fake.sources, hasLength(1));
    expect(fake.sources.first.title, 'Lecture 4 — Photosynthesis');
    expect(find.text('Lecture 4 — Photosynthesis'), findsOneWidget);
    // Processing state label is honest about indexing.
    expect(find.text('Indexing'), findsOneWidget);
  });

  testWidgets('empty paste shows a validation error instead of submitting',
      (tester) async {
    await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();

    expect(find.text('Add a title and the text you want to study.'), findsOneWidget);
  });
}
