import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/quizzes/quiz_models.dart';

import 'helpers.dart';

QuizSummary quiz(
  int n, {
  int questions = 2,
  int? bestScore,
  int attempts = 1,
}) => QuizSummary(
  id: 'quiz-$n',
  title: 'VLSI Unit 3 quiz',
  questionCount: questions,
  difficulty: 'medium',
  attempts: attempts,
  bestScore: bestScore,
  bestTotal: bestScore == null ? null : questions,
  createdAt: DateTime(2026, 8, 1),
);

List<QuizQuestion> sampleQuestions() => const [
  QuizQuestion(
    id: 'q1',
    question: 'What is threshold voltage?',
    options: [
      'Oxide thickness',
      'Gate voltage where the channel conducts',
      'Body bias',
      'Drain current',
    ],
    correctIndex: 1,
    explanation:
        'Threshold voltage is the gate voltage at which the channel begins to conduct.',
  ),
  QuizQuestion(
    id: 'q2',
    question: 'What is Vt?',
    options: ['Threshold voltage', 'Drain voltage'],
    correctIndex: 0,
    explanation: 'Vt is the threshold voltage.',
  ),
];

/// Navigate from the dashboard to the quizzes screen.
Future<void> openQuizzes(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.text('Ready to study?')));
  router.push('/quizzes');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quiz list shows quizzes with attempt stats', (tester) async {
    await pumpApp(
      tester,
      quizzes: FakeQuizzesRepository(
        quizzes: [quiz(1, bestScore: 1, attempts: 2)],
      ),
    );
    await openQuizzes(tester);

    expect(find.text('VLSI Unit 3 quiz'), findsOneWidget);
    expect(find.textContaining('best 1/2'), findsOneWidget);
    expect(find.textContaining('2 attempts'), findsOneWidget);
  });

  testWidgets('empty quiz list shows a helpful empty state', (tester) async {
    await pumpApp(tester, quizzes: FakeQuizzesRepository(quizzes: const []));
    await openQuizzes(tester);
    expect(find.text('No quizzes yet'), findsOneWidget);
    expect(find.text('Generate a quiz'), findsOneWidget);
  });

  testWidgets('list failure shows a friendly error with retry', (tester) async {
    final quizzes = FakeQuizzesRepository(failList: true);
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    expect(find.text('Could not load your quizzes'), findsOneWidget);

    quizzes.failList = false;
    quizzes.quizzes = [quiz(1)];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('VLSI Unit 3 quiz'), findsOneWidget);
  });

  testWidgets('generating a quiz from a notebook navigates to the session', (
    tester,
  ) async {
    final quizzes = FakeQuizzesRepository(questions: sampleQuestions());
    final notebooks = FakeNotebooksRepository();
    notebooks.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'VLSI Unit 3',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    await pumpApp(tester, quizzes: quizzes, notebooks: notebooks);
    await openQuizzes(tester);

    await tester.tap(find.text('New quiz'));
    await tester.pumpAndSettle();

    expect(find.text('VLSI Unit 3'), findsOneWidget); // notebook option

    await tester.tap(find.text('VLSI Unit 3'));
    await tester.pumpAndSettle();

    expect(quizzes.generateCalls, 1);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('What is threshold voltage?'), findsOneWidget);
  });

  testWidgets('generate failure shows a friendly message in the sheet', (
    tester,
  ) async {
    final quizzes = FakeQuizzesRepository(
      questions: sampleQuestions(),
      failGenerate: true,
    );
    final notebooks = FakeNotebooksRepository();
    notebooks.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'VLSI Unit 3',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    await pumpApp(tester, quizzes: quizzes, notebooks: notebooks);
    await openQuizzes(tester);

    await tester.tap(find.text('New quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VLSI Unit 3'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This notebook has no indexed sources yet. Add a source first.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('answering questions shows feedback and a scored result', (
    tester,
  ) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI Unit 3 quiz'));
    await tester.pumpAndSettle();

    // Q1: wrong answer → feedback + explanation.
    await tester.tap(find.text('Oxide thickness'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite'), findsOneWidget);
    expect(
      find.textContaining('Threshold voltage is the gate voltage'),
      findsOneWidget,
    );

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    // Q2: correct answer.
    await tester.tap(find.text('Threshold voltage'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);

    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    // Results breakdown + the answers were submitted to the backend fake.
    expect(find.text('Good work'), findsOneWidget);
    expect(find.text('You answered 2 of 2 correctly.'), findsOneWidget);
    expect(quizzes.submitCalls, 1);
    expect(quizzes.lastAnswers, [0, 0]); // wrong + correct
  });

  testWidgets('a wrong answer reveals the correct option immediately', (
    tester,
  ) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI Unit 3 quiz'));
    await tester.pumpAndSettle();

    // Q1: pick the wrong option (Oxide thickness, correct is index 1).
    await tester.tap(find.text('Oxide thickness'));
    await tester.pumpAndSettle();

    // Immediate feedback: the correct option is revealed with a check icon
    // and the chosen wrong option carries its own icon — never color alone.
    // (cancel/cancel_outlined share a codepoint here, so assert structurally.)
    expect(find.text('Not quite'), findsOneWidget);
    final sessionList = find.byType(ListView).last;
    expect(
      find.descendant(
        of: sessionList,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    final wrongOption = find
        .ancestor(
          of: find.text('Oxide thickness'),
          matching: find.byType(Material),
        )
        .first;
    expect(
      find.descendant(of: wrongOption, matching: find.byType(Icon)),
      findsOneWidget,
    );
    expect(quizzes.lastAnswers, isNull); // nothing submitted yet
  });

  testWidgets('the correct-so-far counter updates as you advance', (
    tester,
  ) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI Unit 3 quiz'));
    await tester.pumpAndSettle();

    expect(find.text('0 correct so far'), findsOneWidget);
    await tester.tap(find.text('Gate voltage where the channel conducts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('1 correct so far'), findsOneWidget);
    expect(find.text('Question 2 of 2'), findsOneWidget);
  });

  testWidgets('reduced motion still runs the full quiz flow', (tester) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI Unit 3 quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oxide thickness'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite'), findsOneWidget);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Threshold voltage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Good work'), findsOneWidget);
    expect(find.text('You answered 2 of 2 correctly.'), findsOneWidget);
    expect(quizzes.submitCalls, 1);
  });

  testWidgets('submit failure surfaces a friendly error', (tester) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
      failSubmit: true,
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI Unit 3 quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oxide thickness'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Threshold voltage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Could not score your answers.'), findsOneWidget);
  });
}
