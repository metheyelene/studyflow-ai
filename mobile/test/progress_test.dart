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

    // The screen asks one question and answers it honestly.
    expect(find.text('YOUR LEARNING'), findsOneWidget);
    expect(find.text('—%'), findsOneWidget); // ring shows no mastery yet
    expect(
      find.textContaining('Review a deck to build mastery'),
      findsOneWidget,
    );
    expect(find.text('No review data yet.'), findsOneWidget);
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

      // Weakest first: Thermo (0%) sits above VLSI Unit 3 (75%).
      expect(find.text('WEAKEST TOPICS'), findsOneWidget);
      final thermoY = tester.getTopLeft(find.text('THERMO')).dy;
      final vlsiY = tester.getTopLeft(find.text('VLSI UNIT 3')).dy;
      expect(thermoY, lessThan(vlsiY));
      expect(find.textContaining('4 reviews'), findsOneWidget);

      // The weakest deck drives the single recommended action.
      expect(find.text('REINFORCE THERMO'), findsOneWidget);
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
    expect(find.textContaining('Could not load flashcard history'), findsOneWidget);

    failNext = false;
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget); // mastery ring recovered
    expect(find.text('REINFORCE THERMO'), findsOneWidget);
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
