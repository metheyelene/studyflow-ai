import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  testWidgets('quiz list shows quizzes with counts', (tester) async {
    await pumpApp(
      tester,
      quizzes: FakeQuizzesRepository(
        quizzes: [quiz(1, bestScore: 1, attempts: 2)],
      ),
    );
    await openQuizzes(tester);

    expect(find.text('VLSI UNIT 3 QUIZ'), findsOneWidget);
    expect(find.textContaining('2 questions'), findsOneWidget);
  });

  testWidgets('empty quiz list shows the honest empty state', (tester) async {
    await pumpApp(tester, quizzes: FakeQuizzesRepository(quizzes: const []));
    await openQuizzes(tester);
    expect(find.text('NO QUIZZES'), findsOneWidget);
  });

  testWidgets('list failure shows a friendly error with retry', (tester) async {
    final quizzes = FakeQuizzesRepository(failList: true);
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    expect(find.textContaining('Could not load your quizzes'), findsOneWidget);

    quizzes.failList = false;
    quizzes.quizzes = [quiz(1)];
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(find.text('VLSI UNIT 3 QUIZ'), findsOneWidget);
  });

  testWidgets('quiz session loads and shows questions', (tester) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI UNIT 3 QUIZ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Question 1 of 2'), findsOneWidget);
    expect(find.text('What is threshold voltage?'), findsOneWidget);
  });

  testWidgets('answering questions and seeing results', (tester) async {
    final quizzes = FakeQuizzesRepository(
      quizzes: [quiz(1)],
      questions: sampleQuestions(),
    );
    await pumpApp(tester, quizzes: quizzes);
    await openQuizzes(tester);

    await tester.tap(find.text('VLSI UNIT 3 QUIZ'));
    await tester.pumpAndSettle();

    // Q1: wrong answer
    await tester.tap(find.text('Oxide thickness'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEXT QUESTION'));
    await tester.pumpAndSettle();

    // Q2: correct answer
    await tester.tap(find.text('Threshold voltage'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();

    expect(find.text('Good work'), findsOneWidget);
    expect(find.textContaining('You answered'), findsOneWidget);
    expect(quizzes.submitCalls, 1);
  });

  testWidgets('session shows an honest error when the quiz is missing', (
    tester,
  ) async {
    await pumpApp(tester, quizzes: FakeQuizzesRepository(quizzes: const []));

    final router = GoRouter.of(tester.element(find.text('Ready to study?')));
    router.push('/quizzes/missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load this quiz'), findsOneWidget);
  });
}
