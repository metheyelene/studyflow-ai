import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';

import 'helpers.dart';

void main() {
  group('parseChatReply', () {
    test('parses the answer and citation trailer', () {
      const body =
          'Photosynthesis converts light energy into chemical energy.\n\n'
          '__SF_CITATIONS__{"citations":[{"marker":1,"chunkId":"c1","sourceId":"s1",'
          '"sourceTitle":"Biology Notes","page":12,"excerpt":"Photosynthesis converts '
          'light energy into chemical energy."}]}';

      final reply = parseChatReply(body);

      expect(
        reply.answer,
        'Photosynthesis converts light energy into chemical energy.',
      );
      expect(reply.citations, hasLength(1));
      expect(reply.citations.first.marker, 1);
      expect(reply.citations.first.sourceTitle, 'Biology Notes');
      expect(reply.citations.first.page, 12);
    });

    test('no trailer: whole body is the answer, no citations', () {
      final reply = parseChatReply('A plain answer without citations.');

      expect(reply.answer, 'A plain answer without citations.');
      expect(reply.citations, isEmpty);
    });

    test('malformed trailer never loses the answer text', () {
      final reply = parseChatReply('An answer.\n\n__SF_CITATIONS__{not json');

      expect(reply.answer, 'An answer.');
      expect(reply.citations, isEmpty);
    });

    test('citation label includes the page when present', () {
      const withPage = ChatCitation(
        marker: 2,
        sourceId: 's1',
        sourceTitle: 'Textbook',
        page: 87,
        excerpt: '…',
      );
      const withoutPage = ChatCitation(
        marker: 3,
        sourceId: 's2',
        sourceTitle: 'Lecture notes',
        excerpt: '…',
      );

      expect(withPage.label, 'Textbook · p. 87');
      expect(withoutPage.label, 'Lecture notes');
    });
  });

  group('notebook AI chat', () {
    testWidgets('asking a question shows the grounded answer with citations', (
      tester,
    ) async {
      final fake = FakeNotebooksRepository();
      fake.notebooks.add(
        Notebook(
          id: 'nb-1',
          title: 'Cell Biology',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await pumpApp(tester, notebooks: fake);

      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cell Biology'));
      await tester.pumpAndSettle();

      // Ask-AI tab is selected by default? No — Sources is tab 0.
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Explain photosynthesis');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      expect(fake.chatCalls, 1);
      expect(fake.chatQuestions, ['Explain photosynthesis']);
      expect(
        find.text(
          'Photosynthesis converts light into chemical energy, as covered in your notes.',
        ),
        findsOneWidget,
      );
      // Citation chip renders with source title.
      expect(find.textContaining('Biology Notes'), findsOneWidget);
    });

    testWidgets('tapping a citation opens the source excerpt', (tester) async {
      final fake = FakeNotebooksRepository();
      fake.notebooks.add(
        Notebook(
          id: 'nb-1',
          title: 'Cell Biology',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await pumpApp(tester, notebooks: fake);

      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cell Biology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Explain photosynthesis');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Biology Notes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Photosynthesis converts light energy into chemical energy.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a failed answer surfaces a friendly error and keeps the question',
      (tester) async {
        final fake = FakeNotebooksRepository();
        fake.failChat = true;
        fake.notebooks.add(
          Notebook(
            id: 'nb-1',
            title: 'Cell Biology',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        await pumpApp(tester, notebooks: fake);

        await tester.tap(find.text('Notebooks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cell Biology'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ask AI'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Explain photosynthesis',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ask'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'The AI could not answer that. Try rephrasing the question.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Explain photosynthesis'),
          findsOneWidget,
        ); // question kept
      },
    );
  });
}
