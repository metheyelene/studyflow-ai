import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/tts/tts_service.dart';
import 'package:studyflow_mobile/features/notebooks/note_assist.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';

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

const _notes = 'Mitochondria generate ATP through cellular respiration.';

/// The paste-sheet text field (the note editor), found by its hint inside
/// the sheet (the notebook pane behind has no such field).
Finder _noteField() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Paste your notes here…',
  ),
);

/// A label inside the floating AI toolbar only (the notebook pane behind
/// the sheet also has a "Quiz" chip, so bare text finders collide).
Finder _toolbarText(String label) => find.descendant(
  of: find.byKey(const ValueKey('selection-ai-toolbar')),
  matching: find.text(label),
);

Future<FakeNotebooksRepository> _openEditor(
  WidgetTester tester, {
  TtsService? tts,
}) async {
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
  await tester.tap(find.text('Paste text'));
  await tester.pumpAndSettle();
  return fake;
}

/// Focuses the note editor and selects [base]..[extent] of [_notes].
Future<void> _selectText(
  WidgetTester tester, {
  int base = 0,
  int extent = 12,
}) async {
  await tester.enterText(_noteField(), _notes);
  await tester.pumpAndSettle();
  final editable = tester.state<EditableTextState>(
    find.descendant(of: _noteField(), matching: find.byType(EditableText)),
  );
  editable.updateEditingValue(
    TextEditingValue(
      text: _notes,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the toolbar appears only while text is selected', (
    tester,
  ) async {
    await _openEditor(tester);

    // Collapsed caret — no toolbar yet.
    expect(_toolbarText('Explain'), findsNothing);

    await _selectText(tester);
    expect(_toolbarText('Explain'), findsOneWidget);
    expect(_toolbarText('Summarize'), findsOneWidget);
    expect(_toolbarText('Simplify'), findsOneWidget);
    expect(_toolbarText('Quiz'), findsOneWidget);
    expect(_toolbarText('Listen'), findsOneWidget);

    // Collapsing the selection hides the toolbar again.
    final editable = tester.state<EditableTextState>(
      find.descendant(of: _noteField(), matching: find.byType(EditableText)),
    );
    editable.updateEditingValue(
      const TextEditingValue(
        text: _notes,
        selection: TextSelection.collapsed(offset: _notes.length),
      ),
    );
    await tester.pumpAndSettle();
    expect(_toolbarText('Explain'), findsNothing);
  });

  testWidgets('Explain transforms the selection and inserts it below', (
    tester,
  ) async {
    final fake = await _openEditor(tester);
    await _selectText(tester);

    await tester.tap(_toolbarText('Explain'));
    await tester.pumpAndSettle();

    expect(fake.assistCalls, 1);
    expect(fake.lastAssistMode, NoteAssistMode.explain);
    expect(fake.lastAssistText, 'Mitochondria');

    final controller = tester.widget<TextField>(_noteField()).controller!;
    expect(controller.text, contains('▸ EXPLAINED'));
    expect(controller.text, contains('EXPLAIN: assisted “Mitochondria”'));
    // The insertion collapsed the caret, so the toolbar is gone.
    expect(_toolbarText('Explain'), findsNothing);
  });

  testWidgets('Summarize, Simplify, and Quiz each call their own mode', (
    tester,
  ) async {
    final fake = await _openEditor(tester);
    await _selectText(tester);

    await tester.tap(_toolbarText('Summarize'));
    await tester.pumpAndSettle();
    expect(fake.lastAssistMode, NoteAssistMode.summarize);

    await _selectText(tester);
    await tester.tap(_toolbarText('Simplify'));
    await tester.pumpAndSettle();
    expect(fake.lastAssistMode, NoteAssistMode.simplify);

    await _selectText(tester);
    await tester.tap(_toolbarText('Quiz'));
    await tester.pumpAndSettle();
    expect(fake.lastAssistMode, NoteAssistMode.quiz);
    expect(fake.lastAssistText, 'Mitochondria');
  });

  testWidgets('a failed transform shows a friendly error and keeps the text', (
    tester,
  ) async {
    final fake = await _openEditor(tester);
    fake.assistOverride = (mode, text) async =>
        throw const NotebooksException('The AI could not process that.');
    await _selectText(tester);

    await tester.tap(_toolbarText('Explain'));
    await tester.pumpAndSettle();

    expect(find.text('The AI could not process that.'), findsOneWidget);
    final controller = tester.widget<TextField>(_noteField()).controller!;
    expect(controller.text, _notes);
    expect(controller.text, isNot(contains('EXPLAINED')));
  });

  testWidgets('Listen reads the selection aloud and Stop silences it', (
    tester,
  ) async {
    final tts = FakeTtsService();
    await _openEditor(tester, tts: tts);
    await _selectText(tester);

    await tester.tap(_toolbarText('Listen'));
    await tester.pumpAndSettle();
    expect(tts.spoken, ['Mitochondria']);
    expect(_toolbarText('Stop'), findsOneWidget);

    await tester.tap(_toolbarText('Stop'));
    await tester.pumpAndSettle();
    expect(tts.stopCalls, 1);
    expect(_toolbarText('Listen'), findsOneWidget);
  });
}
