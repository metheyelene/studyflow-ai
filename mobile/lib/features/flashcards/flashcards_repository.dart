import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'flashcard_models.dart';

/// Flashcard data access. [FlashcardsException] carries a user-safe message.
abstract class FlashcardsRepository {
  Future<List<FlashcardDeck>> list();
  Future<FlashcardDeckDetail> generate(String notebookId, {String? title});
  Future<FlashcardDeckDetail> deck(String deckId);
  Future<void> delete(String deckId);

  /// Best-effort: records one rating; throws only so the caller can decide.
  Future<void> review(
    String deckId, {
    required String cardId,
    required int rating,
  });

  /// Review-history aggregates for the Progress screen (cards reviewed,
  /// per-deck accuracy from the backend's flashcard_reviews table).
  Future<FlashcardProgress> progress();
}

class ApiFlashcardsRepository implements FlashcardsRepository {
  ApiFlashcardsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FlashcardDeck>> list() async {
    final res = await _client.get<dynamic>('/api/flashcards');
    final data = res.data;
    final list = data is Map ? data['decks'] : null;
    if (list is! List) {
      throw const FlashcardsException('Could not load your decks.');
    }
    return [
      for (final d in list)
        if (d is Map) FlashcardDeck.fromJson(Map<String, dynamic>.from(d)),
    ];
  }

  @override
  Future<FlashcardDeckDetail> generate(
    String notebookId, {
    String? title,
  }) async {
    final res = await _client.post<dynamic>(
      '/api/flashcards',
      data: {
        'notebookId': notebookId,
        if (title != null && title.isNotEmpty) 'title': title,
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw const FlashcardsException('Could not generate that deck.');
    }
    final deckJson = data['deck'];
    final cards = data['cards'];
    if (deckJson is! Map || cards is! List) {
      throw const FlashcardsException('Could not generate that deck.');
    }
    return FlashcardDeckDetail(
      deck: FlashcardDeck.fromJson(Map<String, dynamic>.from(deckJson)),
      cards: [
        for (final c in cards)
          if (c is Map) Flashcard.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }

  @override
  Future<FlashcardDeckDetail> deck(String deckId) async {
    final res = await _client.get<dynamic>('/api/flashcards/$deckId');
    final data = res.data;
    if (data is! Map) {
      throw const FlashcardsException('Could not load that deck.');
    }
    final deckJson = data['deck'];
    final cards = data['cards'];
    if (deckJson is! Map || cards is! List) {
      throw const FlashcardsException('Could not load that deck.');
    }
    return FlashcardDeckDetail(
      deck: FlashcardDeck.fromJson(Map<String, dynamic>.from(deckJson)),
      cards: [
        for (final c in cards)
          if (c is Map) Flashcard.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }

  @override
  Future<void> delete(String deckId) =>
      _client.delete<dynamic>('/api/flashcards/$deckId');

  @override
  Future<void> review(
    String deckId, {
    required String cardId,
    required int rating,
  }) async {
    await _client.post<dynamic>(
      '/api/flashcards/$deckId/review',
      data: {'cardId': cardId, 'rating': rating},
    );
  }

  @override
  Future<FlashcardProgress> progress() async {
    final res = await _client.get<dynamic>('/api/progress/flashcards');
    final data = res.data;
    if (data is! Map) {
      throw const FlashcardsException('Could not load your flashcard history.');
    }
    return FlashcardProgress.fromJson(Map<String, dynamic>.from(data));
  }
}

class FlashcardsException implements Exception {
  const FlashcardsException(this.message);
  final String message;
}

final flashcardsRepositoryProvider = Provider<FlashcardsRepository>(
  (ref) => ApiFlashcardsRepository(ref.watch(apiClientProvider)),
);
