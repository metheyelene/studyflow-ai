import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/tts/tts_service.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
import 'package:studyflow_mobile/shared/widgets/swiss/swiss_components.dart';

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

/// Helper to open a notebook and navigate to the ASK AI tab.
Future<void> _openChatTab(WidgetTester tester) async {
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
  await tester.tap(find.text('NOTEBOOKS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CELL BIOLOGY'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ASK AI'));
  await tester.pumpAndSettle();
  return;
}

/// Helper to send a message in the chat.
Future<void> _sendMessage(WidgetTester tester, String message) async {
  // Find the text field, focus it, enter text, then send
  final textField = find.byType(TextField);
  await tester.showKeyboard(textField);
  await tester.enterText(textField, message);
  await tester.pump();
  // Find the send SwissButton and invoke onPressed directly
  final askBtn = find.byWidgetPredicate(
    (w) => w is SwissButton && w.label == 'Ask' && w.onPressed != null,
  );
  expect(askBtn, findsOneWidget);
  tester.widget<SwissButton>(askBtn).onPressed!();
  await tester.pump();
  await tester.pumpAndSettle();
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
      await _openChatTab(tester);
      await _sendMessage(tester, 'Explain photosynthesis');

      // The fake repository returns a chat call
      expect(find.text('Explain photosynthesis'), findsOneWidget);
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
      await _openChatTab(tester);
      await _sendMessage(tester, 'Explain photosynthesis');

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

        await tester.tap(find.text('NOTEBOOKS'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CELL BIOLOGY'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ASK AI'));
        await tester.pumpAndSettle();

        await _sendMessage(tester, 'Explain photosynthesis');

        expect(
          find.textContaining(
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
      'the empty state shows ASK STUDYFLOW heading and suggestions',
      (tester) async {
        _freezeOrbMotion(tester);
        await _openChatTab(tester);

        // The empty state has the ASK STUDYFLOW heading
        final emptyState = find.byKey(const Key('chat-empty-state'));
        expect(emptyState, findsOneWidget);
        expect(
          find.descendant(
            of: emptyState,
            matching: find.text('ASK STUDYFLOW'),
          ),
          findsOneWidget,
        );

        // Suggestion chips
        await tester.ensureVisible(find.text('SUMMARIZE THIS NOTEBOOK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SUMMARIZE THIS NOTEBOOK'));
        await tester.pumpAndSettle();

        // The suggestion sends a prompt
        expect(find.text('SUMMARIZE THIS NOTEBOOK'), findsNothing);
      },
    );

    testWidgets(
      'answers show AI label, content, and contextual actions',
      (tester) async {
        _freezeOrbMotion(tester);
        await _openChatTab(tester);
        await _sendMessage(tester, 'Explain photosynthesis');

        // The response shows AI label
        expect(find.text('AI'), findsOneWidget);
        expect(
          find.text(
            'Photosynthesis converts light into chemical energy, as covered in your notes.',
          ),
          findsOneWidget,
        );

        // Action labels: LISTEN, FLASHCARDS, QUIZ
        expect(find.text('LISTEN'), findsOneWidget);
        expect(find.text('FLASHCARDS'), findsOneWidget);
        expect(find.text('QUIZ'), findsOneWidget);
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

      await tester.tap(find.text('NOTEBOOKS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CELL BIOLOGY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ASK AI'));
      await tester.pumpAndSettle();

      await _sendMessage(tester, 'Explain photosynthesis');

      // Tap the LISTEN action (SwissButton uppercases the label)
      await tester.tap(find.text('LISTEN'));
      await tester.pumpAndSettle();

      expect(
        tts.spoken,
        contains(
          'Photosynthesis converts light into chemical energy, as covered in your notes.',
        ),
      );
      expect(find.text('STOP'), findsOneWidget);

      await tester.tap(find.text('STOP'));
      await tester.pumpAndSettle();

      expect(tts.stopCalls, 1);
      expect(find.text('LISTEN'), findsOneWidget);
    });
  });
}
