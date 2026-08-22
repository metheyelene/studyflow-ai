import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:studyflow_mobile/features/flashcards/flashcard_models.dart';

import 'helpers.dart';

FlashcardDeck deck(int n, {int cards = 2}) => FlashcardDeck(
  id: 'deck-$n',
  title: 'VLSI Unit 3 flashcards',
  cardCount: cards,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 10),
);

List<Flashcard> sampleCards() => const [
  Flashcard(
    id: 'c-1',
    front: 'What is threshold voltage?',
    back: 'The gate voltage where the channel conducts.',
  ),
  Flashcard(id: 'c-2', front: 'What is Vt?', back: 'Threshold voltage.'),
];

/// Navigate from the dashboard to the flashcards screen.
Future<void> openFlashcards(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.text('Ready to study?')));
  router.push('/flashcards');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deck list shows decks with counts', (tester) async {
    final flashcards = FakeFlashcardsRepository(decks: [deck(1, cards: 3)]);
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    expect(find.text('FLASHCARDS'), findsWidgets);
    expect(find.text('VLSI UNIT 3 FLASHCARDS'), findsOneWidget);
    expect(find.textContaining('3 cards'), findsOneWidget);
  });

  testWidgets('no decks shows the honest empty state', (tester) async {
    await pumpApp(
      tester,
      flashcards: FakeFlashcardsRepository(decks: const []),
    );
    await openFlashcards(tester);

    expect(find.text('NO FLASHCARDS'), findsOneWidget);
  });

  testWidgets('deck list failure shows a friendly error with retry', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(failList: true);
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    expect(find.textContaining('Could not load your flashcards'), findsOneWidget);

    flashcards.failList = false;
    flashcards.decks = [deck(1)];
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(find.text('VLSI UNIT 3 FLASHCARDS'), findsOneWidget);
  });

  testWidgets('study session: flip, rate, and finish with a summary', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      decks: [deck(1, cards: 2)],
      cards: sampleCards(),
    );
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    // Open the deck.
    await tester.tap(find.text('VLSI UNIT 3 FLASHCARDS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Card 1 of 2'), findsOneWidget);
    expect(find.text('What is threshold voltage?'), findsOneWidget);

    // Flip reveals the answer and the rating row.
    await tester.tap(find.text('What is threshold voltage?'));
    await tester.pumpAndSettle();
    expect(
      find.text('The gate voltage where the channel conducts.'),
      findsOneWidget,
    );
    expect(find.text('How well did you know it?'), findsOneWidget);

    // Rate "Good" (4) → next card.
    await tester.tap(find.text('GOOD'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Card 2 of 2'), findsOneWidget);

    // Flip and rate "Easy" (5).
    await tester.tap(find.text('What is Vt?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EASY'));
    await tester.pumpAndSettle();

    // Summary with the recorded ratings.
    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.textContaining('You reviewed 2 cards'), findsOneWidget);

    expect(flashcards.reviews, hasLength(2));
    expect(flashcards.reviews[0].$3, 4); // Good
    expect(flashcards.reviews[1].$3, 5); // Easy
  });

  testWidgets('session shows an honest error when the deck is missing', (
    tester,
  ) async {
    await pumpApp(
      tester,
      flashcards: FakeFlashcardsRepository(decks: const []),
    );

    final router = GoRouter.of(tester.element(find.text('Ready to study?')));
    router.push('/flashcards/missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load this deck'), findsOneWidget);
  });
}
