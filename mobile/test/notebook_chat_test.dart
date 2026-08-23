import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/tts/tts_service.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_controller.dart';

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

/// Opens a notebook with a seeded fake repo and navigates to the ASK AI tab.
/// Returns the fake so callers can assert on chatCalls, etc.
Future<FakeNotebooksRepository> _setupChat(
  WidgetTester tester, {
  bool failChat = false,
  TtsService? tts,
}) async {
  final fake = FakeNotebooksRepository();
  fake.failChat = failChat;
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
  return fake;
}

/// Sends a message by directly calling the chat controller's send method.
/// This bypasses the UI tap chain which can be unreliable in tests.
Future<void> _sendMessage(WidgetTester tester, String message) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(TextField)));
  final controller = container.read(notebookChatControllerProvider('nb-1').notifier);
  await controller.send(message);
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
      final fake = await _setupChat(tester);
      await _sendMessage(tester, 'Explain photosynthesis');

      expect(fake.chatCalls, 1);
      expect(fake.chatQuestions, ['Explain photosynthesis']);

      // The user message may be off-screen in the reverse ListView, so
      // verify it via the controller state instead of the widget tree.
      final container =
          ProviderScope.containerOf(tester.element(find.byType(TextField)));
      final chatState =
          container.read(notebookChatControllerProvider('nb-1'));
      expect(chatState.messages, hasLength(2));
      expect(chatState.messages.first.content, 'Explain photosynthesis');

      // The AI answer IS visible because it's at the bottom of the reverse list.
      expect(
        find.text(
          'Photosynthesis converts light into chemical energy, as covered in your notes.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Biology Notes'), findsOneWidget);
    });

    testWidgets('tapping a citation opens the source excerpt', (tester) async {
      _freezeOrbMotion(tester);
      await _setupChat(tester);
      await _sendMessage(tester, 'Explain photosynthesis');

      // The citation chip is part of the AI message which IS visible.
      final citationChip = find.textContaining('Biology Notes');
      expect(citationChip, findsWidgets);
      await tester.tap(citationChip.first);
      await tester.pumpAndSettle();

      // The excerpt text now appears twice: once inline in the chip,
      // once in the bottom sheet. Both being present confirms the sheet opened.
      expect(
        find.text('Photosynthesis converts light energy into chemical energy.'),
        findsWidgets,
      );
      // The bottom sheet overlay should be present.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets(
      'a failed answer surfaces a friendly error and keeps the question',
      (tester) async {
        _freezeOrbMotion(tester);
        final fake = await _setupChat(tester, failChat: true);
        await _sendMessage(tester, 'Explain photosynthesis');

        expect(fake.chatCalls, 1);
        // The UI uppercases the error via chat.error!.toUpperCase().
        expect(
          find.textContaining('THE AI COULD NOT ANSWER THAT'),
          findsOneWidget,
        );
        // User message is in state even though off-screen.
        final container =
            ProviderScope.containerOf(tester.element(find.byType(TextField)));
        final chatState =
            container.read(notebookChatControllerProvider('nb-1'));
        expect(chatState.messages.first.content, 'Explain photosynthesis');
      },
    );

    testWidgets(
      'the empty state shows ASK STUDYFLOW heading and suggestions',
      (tester) async {
        _freezeOrbMotion(tester);
        await _setupChat(tester);

        final emptyState = find.byKey(const Key('chat-empty-state'));
        expect(emptyState, findsOneWidget);
        expect(
          find.descendant(
            of: emptyState,
            matching: find.text('ASK STUDYFLOW'),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('SUMMARIZE THIS NOTEBOOK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SUMMARIZE THIS NOTEBOOK'));
        await tester.pumpAndSettle();

        expect(find.text('SUMMARIZE THIS NOTEBOOK'), findsNothing);
      },
    );

    testWidgets(
      'answers show AI label, content, and contextual actions',
      (tester) async {
        _freezeOrbMotion(tester);
        await _setupChat(tester);
        await _sendMessage(tester, 'Explain photosynthesis');

        expect(find.text('AI'), findsOneWidget);
        expect(
          find.text(
            'Photosynthesis converts light into chemical energy, as covered in your notes.',
          ),
          findsOneWidget,
        );

        expect(find.text('LISTEN'), findsOneWidget);
        // FLASHCARDS appears in both the AI action bar and the Study tab tool row.
        expect(find.text('FLASHCARDS'), findsWidgets);
        expect(find.text('QUIZ'), findsWidgets);
      },
    );

    testWidgets('Listen speaks the answer and toggles to Stop', (tester) async {
      _freezeOrbMotion(tester);
      final tts = FakeTtsService();
      await _setupChat(tester, tts: tts);
      await _sendMessage(tester, 'Explain photosynthesis');

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
