import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/tts/tts_service.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
import 'package:studyflow_mobile/shared/widgets/ai/studyflow_ai_orb.dart';

import 'helpers.dart';

/// In-memory TTS recorder: never touches platform channels, and lets the
/// test drive the speaking state directly.
class FakeTtsService implements TtsService {
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);
  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    _speaking.value = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _speaking.value = false;
  }
}

/// The chat's empty-state anchor is the StudyFlow orb, which breathes
/// while idle. `pumpAndSettle` can never settle an infinite animation, so
/// these tests run with the app's own reduced-motion contract — exactly
/// how ai_orb_test freezes the orb.
void _freezeOrbMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

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
      _freezeOrbMotion(tester);
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
      _freezeOrbMotion(tester);
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
        _freezeOrbMotion(tester);
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

    testWidgets(
      'the empty state anchors on the orb and suggestions send prompts',
      (tester) async {
        _freezeOrbMotion(tester);
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

        // Reading-first welcome: the orb anchor and an editorial headline
        // replace the old boxed empty state (the hero's Ask StudyFlow CTA
        // sits above the tab bar, so scope by the empty-state key).
        final emptyState = find.byKey(const Key('chat-empty-state'));
        expect(emptyState, findsOneWidget);
        expect(
          find.descendant(of: emptyState, matching: find.text('Ask StudyFlow')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: emptyState,
            matching: find.byKey(kStudyFlowAiOrb),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Summarize this notebook'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Summarize this notebook'));
        await tester.pumpAndSettle();

        expect(fake.chatCalls, 1);
        expect(fake.chatQuestions, ['Summarize this notebook']);
      },
    );

    testWidgets(
      'answers render reading-first with sources and contextual actions',
      (tester) async {
        _freezeOrbMotion(tester);
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

        await tester.enterText(
          find.byType(TextField),
          'Explain photosynthesis',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ask'));
        await tester.pumpAndSettle();

        // The response is an editorial block, not a chat bubble: an
        // eyebrow, a SOURCES divider, and contextual actions.
        expect(find.text('STUDYFLOW'), findsOneWidget);
        expect(find.text('SOURCES'), findsOneWidget);

        // The pane's hero chips behind the tab bar also say Flashcards and
        // Quiz, so scope the action assertions to the answer's own row.
        final actions = find.byKey(const Key('chat-answer-actions'));
        expect(actions, findsOneWidget);
        expect(
          find.descendant(of: actions, matching: find.text('Listen')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: actions, matching: find.text('Flashcards')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: actions, matching: find.text('Quiz')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Listen speaks the answer and toggles to Stop', (tester) async {
      _freezeOrbMotion(tester);
      final tts = FakeTtsService();
      final fake = FakeNotebooksRepository();
      fake.notebooks.add(
        Notebook(
          id: 'nb-1',
          title: 'Cell Biology',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await pumpApp(tester, notebooks: fake, tts: tts);

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

      final actions = find.byKey(const Key('chat-answer-actions'));
      await tester.tap(
        find.descendant(of: actions, matching: find.text('Listen')),
      );
      await tester.pumpAndSettle();

      expect(
        tts.spoken,
        contains(
          'Photosynthesis converts light into chemical energy, as covered in your notes.',
        ),
      );
      expect(
        find.descendant(of: actions, matching: find.text('Stop')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: actions, matching: find.text('Stop')),
      );
      await tester.pumpAndSettle();

      expect(tts.stopCalls, 1);
      expect(
        find.descendant(of: actions, matching: find.text('Listen')),
        findsOneWidget,
      );
    });
  });
}
