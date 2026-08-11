import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flashcard_models.dart';
import 'flashcards_repository.dart';

/// Deck list state for the Flashcards screen.
class FlashcardsState {
  const FlashcardsState({required this.decks, this.busy = false, this.error});

  final List<FlashcardDeck> decks;
  final bool busy;
  final String? error;

  FlashcardsState copyWith({List<FlashcardDeck>? decks, bool? busy, String? error, bool clearError = false}) {
    return FlashcardsState(
      decks: decks ?? this.decks,
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class FlashcardsController extends AsyncNotifier<FlashcardsState> {
  @override
  Future<FlashcardsState> build() async {
    final decks = await ref.read(flashcardsRepositoryProvider).list();
    return FlashcardsState(decks: decks);
  }

  FlashcardsRepository get _repo => ref.read(flashcardsRepositoryProvider);

  /// Generates a deck from a notebook and returns it (the caller navigates
  /// to the study session). The list is refreshed from the server so it
  /// stays authoritative; a refresh failure never hides the new deck.
  Future<FlashcardDeckDetail> generate(String notebookId) async {
    final detail = await _repo.generate(notebookId);
    try {
      final decks = await _repo.list();
      state = AsyncData(FlashcardsState(decks: [
        detail.deck,
        ...decks.where((d) => d.id != detail.deck.id),
      ]));
    } catch (_) {
      state = AsyncData(FlashcardsState(decks: [detail.deck]));
    }
    return detail;
  }

  Future<void> delete(String deckId) async {
    await _repo.delete(deckId);
    final current = await future;
    state = AsyncData(
      current.copyWith(decks: current.decks.where((d) => d.id != deckId).toList()),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final decks = await _repo.list();
    state = AsyncData(FlashcardsState(decks: decks));
  }
}

final flashcardsControllerProvider =
    AsyncNotifierProvider<FlashcardsController, FlashcardsState>(FlashcardsController.new);
