import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/note_assist.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_controller.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';
import 'package:studyflow_mobile/features/notebooks/source_upload.dart';

import 'helpers.dart';

void main() {
  Future<void> openNotebooksTab(WidgetTester tester) async {
    await tester.tap(find.text('NOTEBOOKS'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state shows create action', (tester) async {
    await pumpApp(tester);
    await openNotebooksTab(tester);

    expect(find.text('NO STUDY SPACES'), findsOneWidget);
    expect(find.text('CREATE'), findsOneWidget);
  });

  testWidgets('opening a notebook on phone shows the detail workspace', (
    tester,
  ) async {
    final fake = FakeNotebooksRepository();
    fake.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'VLSI Design',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await pumpApp(tester, notebooks: fake);
    await openNotebooksTab(tester);

    await tester.tap(find.text('VLSI DESIGN'));
    await tester.pumpAndSettle();

    // Detail workspace: tabs + honest empty states.
    expect(find.text('SOURCES'), findsOneWidget);
    expect(find.text('ASK AI'), findsOneWidget);
    expect(find.text('STUDY'), findsWidgets);
    expect(find.text('NO SOURCES YET'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('create failure surfaces a friendly error and stays open', (
    tester,
  ) async {
    final repo = _FailingNotebooksRepository();
    await pumpApp(tester, notebooks: repo);
    await openNotebooksTab(tester);

    final createBtn = find.text('CREATE').first;
    await tester.tap(createBtn);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'Fails',
    );
    await tester.tap(find.text('CREATE NOTEBOOK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not create the notebook. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('CREATE NOTEBOOK'), findsOneWidget); // sheet still open

    // Let the toast's dismiss timer elapse before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  test('notebooks controller loads and creates via the repository', () async {
    final container = ProviderContainer(
      overrides: [
        notebooksRepositoryProvider.overrideWithValue(
          FakeNotebooksRepository(),
        ),
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

  @override
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  }) async {
    throw const NotebooksException('Could not reach the AI.');
  }

  @override
  Future<List<NotebookSource>> listSources(String notebookId) async => [];

  @override
  Future<NotebookSource> addPastedSource(
    String notebookId, {
    required String title,
    required String text,
  }) {
    throw const NotebooksException('Could not add the source.');
  }

  @override
  Future<List<NotebookSource>> uploadFiles(
    String notebookId, {
    required List<UploadFile> files,
    void Function(int done, int total)? onProgress,
  }) {
    throw const NotebooksException('Could not upload the files.');
  }

  @override
  Future<void> deleteSource(String notebookId, String sourceId) {
    throw const NotebooksException('Could not remove the source.');
  }

  @override
  Future<String> assistText(
    String notebookId, {
    required NoteAssistMode mode,
    required String text,
  }) {
    throw const NotebooksException('Could not run that AI action.');
  }
}
