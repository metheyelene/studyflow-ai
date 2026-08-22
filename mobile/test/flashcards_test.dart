import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:studyflow_mobile/features/flashcards/flashcard_models.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';

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

  testWidgets('generating a deck from a notebook navigates to the session', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(cards: sampleCards());
    final notebooks = FakeNotebooksRepository();
    notebooks.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'VLSI Unit 3',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
    await pumpApp(tester, flashcards: flashcards, notebooks: notebooks);
    await openFlashcards(tester);

    await tester.tap(find.text('NEW DECK'));
    await tester.pumpAndSettle();

    // The sheet header and the empty-state CTA share the label; the
    // notebook option is the meaningful assertion.
    expect(find.text('VLSI Unit 3'), findsOneWidget); // notebook option

    await tester.tap(find.text('VLSI UNIT 3'));
    await tester.pumpAndSettle();

    expect(flashcards.generateCalls, 1);
    // Landed on the study session for the generated deck.
    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(find.text('What is threshold voltage?'), findsOneWidget);
  });

  testWidgets('generate failure shows a friendly message in the sheet', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      cards: sampleCards(),
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
    await pumpApp(tester, flashcards: flashcards, notebooks: notebooks);
    await openFlashcards(tester);

    await tester.tap(find.text('NEW DECK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VLSI UNIT 3'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This notebook has no indexed sources yet. Add a source first.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleting a deck removes it from the list', (tester) async {
    final flashcards = FakeFlashcardsRepository(decks: [deck(1)]);
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    await tester.tap(find.byTooltip('Delete deck'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this deck?'), findsOneWidget);

    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();

    expect(find.text('NO FLASHCARDS'), findsOneWidget);
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
    await tester.tap(find.text('VLSI Unit 3 flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 2'), findsOneWidget);
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
    await tester.tap(find.text('Good'));  // SwissButton label is uppercased internally
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 2'), findsOneWidget);

    // Flip and rate "Easy" (5).
    await tester.tap(find.text('What is Vt?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    // Summary with the recorded ratings.
    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.text('You reviewed 2 cards.'), findsOneWidget);

    expect(flashcards.reviews, hasLength(2));
    expect(flashcards.reviews[0].$3, 4); // Good
    expect(flashcards.reviews[1].$3, 5); // Easy
  });

  testWidgets('swipe left commits Again and advances to the next card', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      decks: [deck(1, cards: 2)],
      cards: sampleCards(),
    );
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    await tester.tap(find.text('VLSI Unit 3 flashcards'));
    await tester.pumpAndSettle();

    // Flip the card, then swipe it left — a fast drag with velocity.
    await tester.tap(find.text('What is threshold voltage?'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(AnimatedBuilder).last,
      const Offset(-260, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(flashcards.reviews, hasLength(1));
    expect(flashcards.reviews[0].$3, 1); // Again
  });

  testWidgets('swipe right commits Good and springs back otherwise', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      decks: [deck(1, cards: 2)],
      cards: sampleCards(),
    );
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    await tester.tap(find.text('VLSI Unit 3 flashcards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('What is threshold voltage?'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(AnimatedBuilder).last,
      const Offset(260, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(flashcards.reviews, hasLength(1));
    expect(flashcards.reviews[0].$3, 4); // Good
  });

  testWidgets('a short swipe that misses the threshold springs back', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      decks: [deck(1, cards: 2)],
      cards: sampleCards(),
    );
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    await tester.tap(find.text('VLSI Unit 3 flashcards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('What is threshold voltage?'));
    await tester.pumpAndSettle();
    // Slow, short drag — below the 90px / 600 velocity thresholds.
    await tester.drag(find.byType(AnimatedBuilder).last, const Offset(-40, 0));
    await tester.pumpAndSettle();

    // Still on card 1, no rating recorded.
    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(flashcards.reviews, isEmpty);
  });

  testWidgets('reduced motion flips instantly without rating a swipe', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository(
      decks: [deck(1, cards: 2)],
      cards: sampleCards(),
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, flashcards: flashcards);
    await openFlashcards(tester);

    await tester.tap(find.text('VLSI Unit 3 flashcards'));
    await tester.pumpAndSettle();

    // Tap flips without an animation; the answer is immediately visible.
    await tester.tap(find.text('What is threshold voltage?'));
    await tester.pumpAndSettle();
    expect(
      find.text('The gate voltage where the channel conducts.'),
      findsOneWidget,
    );
    expect(find.text('How well did you know it?'), findsOneWidget);

    // A swipe under reduced motion does not commit a rating.
    await tester.fling(
      find.byType(AnimatedBuilder).last,
      const Offset(-260, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(flashcards.reviews, isEmpty);
  });

  testWidgets('session shows an honest error when the deck is missing', (
    tester,
  ) async {
    await pumpApp(
      tester,
      flashcards: FakeFlashcardsRepository(decks: const []),
    );

    // Direct route to a deck that does not exist (e.g. a stale deep link).
    final router = GoRouter.of(tester.element(find.text('Ready to study?')));
    router.push('/flashcards/missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load this deck'), findsOneWidget);
  });
}
