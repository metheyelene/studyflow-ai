import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_controller.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';

import 'helpers.dart';

void main() {
  Future<void> openNotebooksTab(WidgetTester tester) async {
    await tester.tap(find.text('Notebooks'));
    await tester.pumpAndSettle();
  }

  Future<void> createNotebook(WidgetTester tester, String name) async {
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
      name,
    );
    await tester.tap(find.text('Create notebook'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state → create notebook → card appears with search',
      (tester) async {
    await pumpApp(tester);
    await openNotebooksTab(tester);

    expect(find.text('No notebooks yet'), findsOneWidget);

    await createNotebook(tester, 'Cell Biology — Unit 3');
    expect(find.text('Cell Biology — Unit 3'), findsOneWidget);
    expect(find.textContaining('0 sources'), findsOneWidget);

    // Search filters the list.
    await tester.enterText(find.byType(TextField), 'Physics');
    await tester.pumpAndSettle();
    expect(find.text('No matching notebooks'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cell');
    await tester.pumpAndSettle();
    expect(find.text('Cell Biology — Unit 3'), findsOneWidget);
  });

  testWidgets('opening a notebook on phone shows the detail and back returns',
      (tester) async {
    await pumpApp(tester);
    await openNotebooksTab(tester);
    await createNotebook(tester, 'VLSI Design');

    await tester.tap(find.text('VLSI Design'));
    await tester.pumpAndSettle();

    // Detail workspace: tabs + honest empty states.
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Study tools'), findsOneWidget);
    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('VLSI Design'), findsOneWidget);
  });

  testWidgets('tablet/desktop shows master-detail: list + detail panes',
      (tester) async {
    await pumpApp(tester, size: const Size(1024, 768));
    await openNotebooksTab(tester);
    expect(find.text('Select a notebook'), findsOneWidget);

    await createNotebook(tester, 'Thermodynamics');
    expect(find.text('Select a notebook'), findsOneWidget); // still nothing selected

    await tester.tap(find.text('Thermodynamics'));
    await tester.pumpAndSettle();

    expect(find.text('Select a notebook'), findsNothing);
    expect(find.text('No sources yet'), findsOneWidget);
    // Both panes are visible at once on wide screens.
    expect(find.text('Thermodynamics'), findsNWidgets(2)); // list card + detail header
  });

  testWidgets('create failure surfaces a friendly error and stays open',
      (tester) async {
    final repo = _FailingNotebooksRepository();
    await pumpApp(tester, notebooks: repo);
    await openNotebooksTab(tester);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
      'Fails',
    );
    await tester.tap(find.text('Create notebook'));
    await tester.pumpAndSettle();

    expect(find.text('Could not create the notebook. Please try again.'), findsOneWidget);
    expect(find.text('Create notebook'), findsOneWidget); // sheet still open

    // Let the toast's dismiss timer elapse before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  test('notebooks controller loads and creates via the repository', () async {
    final container = ProviderContainer(
      overrides: [
        notebooksRepositoryProvider.overrideWithValue(FakeNotebooksRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(notebooksControllerProvider.notifier);
    // Await the initial load so the async controller is in its data state.
    final initial = await container.read(notebooksControllerProvider.future);
    expect(initial, isEmpty);

    await controller.create('Cell Biology');
    final state = container.read(notebooksControllerProvider);
    expect(state.value!.single.title, 'Cell Biology');
    expect(state.value!.single.sourceCount, 0);
  });
}

class _FailingNotebooksRepository implements NotebooksRepository {
  @override
  Future<List<Notebook>> list() async => [];

  @override
  Future<Notebook> create({required String title, String? description}) {
    throw const NotebooksException('Could not create the notebook.');
  }

  @override
  Future<void> delete(String id) async {}
}
