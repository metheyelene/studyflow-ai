import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/flashcards/flashcard_models.dart';
import 'package:studyflow_mobile/features/flashcards/flashcards_repository.dart';

import 'helpers.dart';

void main() {
  final sampleProgress = FlashcardProgress(
    totalReviews: 6,
    uniqueCards: 3,
    decks: const [
      DeckAccuracy(
        deckId: 'deck_a',
        title: 'VLSI Unit 3',
        reviews: 4,
        remembered: 3,
        accuracy: 75,
      ),
      DeckAccuracy(
        deckId: 'deck_b',
        title: 'Thermo',
        reviews: 2,
        remembered: 0,
        accuracy: 0,
      ),
    ],
  );

  testWidgets('shows an honest empty state when there are no reviews', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository();
    final router = buildAppRouter();
    await pumpApp(tester, router: router, flashcards: flashcards);
    router.go('/progress');
    await tester.pumpAndSettle();

    expect(find.text('FLASHCARD REVIEWS'), findsOneWidget);
    expect(find.textContaining('No flashcard reviews yet'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    // Nothing fabricated: no "Cards reviewed" total is shown.
    expect(find.text('Cards reviewed'), findsNothing);
  });

  testWidgets('shows total cards reviewed and per-deck accuracy', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository()
      ..progressData = sampleProgress;
    final router = buildAppRouter();
    await pumpApp(tester, router: router, flashcards: flashcards);
    router.go('/progress');
    await tester.pumpAndSettle();

    expect(find.text('FLASHCARD REVIEWS'), findsOneWidget);
    expect(find.text('Cards reviewed'), findsOneWidget);
    expect(find.text('6'), findsOneWidget); // total reviews
    expect(find.textContaining('3 cards'), findsOneWidget); // unique cards

    // Per-deck rows with accuracy.
    expect(find.text('VLSI Unit 3'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Thermo'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('4 revs'), findsOneWidget);
  });

  testWidgets('surfaces a load failure with a retry that recovers', (
    tester,
  ) async {
    final flashcards = FakeFlashcardsRepository()
      ..progressData = sampleProgress;
    var failNext = true;
    final failing = _FailingProgressRepository(flashcards, () => failNext);
    final router = buildAppRouter();
    await pumpApp(tester, router: router, flashcards: failing);
    router.go('/progress');
    await tester.pumpAndSettle();
    expect(find.text('Could not load your flashcard history.'), findsOneWidget);

    failNext = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Cards reviewed'), findsOneWidget);
  });
}

class _FailingProgressRepository extends FakeFlashcardsRepository {
  _FailingProgressRepository(this._inner, this._shouldFail);

  final FakeFlashcardsRepository _inner;
  final bool Function() _shouldFail;

  @override
  Future<FlashcardProgress> progress() async {
    if (_shouldFail())
      throw const FlashcardsException('Could not load your flashcard history.');
    return _inner.progressData;
  }
}
