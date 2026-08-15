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

    // The screen asks one question and answers it honestly: no ring
    // percentage, no weak-topic list, one recommended action.
    expect(find.text('How am I doing?'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // ring shows no mastery yet
    expect(
      find.textContaining('Review a deck and your mastery builds'),
      findsOneWidget,
    );
    expect(find.text('Review flashcards'), findsOneWidget);
    expect(find.text('WEAKEST TOPICS FIRST'), findsNothing);
  });

  testWidgets(
    'shows weighted mastery, weakest-first topics, and a real action',
    (tester) async {
      final flashcards = FakeFlashcardsRepository()
        ..progressData = sampleProgress;
      final router = buildAppRouter();
      await pumpApp(tester, router: router, flashcards: flashcards);
      router.go('/progress');
      await tester.pumpAndSettle();

      // Mastery = weighted average accuracy: (75*4 + 0*2) / 6 = 50%.
      expect(find.text('50%'), findsOneWidget); // ring
      expect(find.textContaining('2 decks'), findsOneWidget);
      expect(find.textContaining('6 reviews'), findsOneWidget);

      // Weakest first: Thermo (0%) sits above VLSI Unit 3 (75%).
      expect(find.text('WEAKEST TOPICS FIRST'), findsOneWidget);
      final thermoY = tester.getTopLeft(find.text('Thermo')).dy;
      final vlsiY = tester.getTopLeft(find.text('VLSI Unit 3')).dy;
      expect(thermoY, lessThan(vlsiY));
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.textContaining('4 revs'), findsOneWidget);

      // The weakest deck drives the single recommended action.
      expect(find.text('Reinforce Thermo'), findsOneWidget);
    },
  );

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
    expect(find.text('50%'), findsOneWidget); // mastery ring recovered
    expect(find.text('Reinforce Thermo'), findsOneWidget);
  });
}

class _FailingProgressRepository extends FakeFlashcardsRepository {
  _FailingProgressRepository(this._inner, this._shouldFail);

  final FakeFlashcardsRepository _inner;
  final bool Function() _shouldFail;

  @override
  Future<FlashcardProgress> progress() async {
    if (_shouldFail()) {
      throw const FlashcardsException('Could not load your flashcard history.');
    }
    return _inner.progressData;
  }
}
