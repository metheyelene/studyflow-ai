/// Per-deck review aggregate from the backend (accuracy = % of reviews
/// rated Hard(3)/Good(4)/Easy(5) — i.e. remembered; Again(1) counts as
/// forgotten, matching the session's rating scale).
class DeckAccuracy {
  const DeckAccuracy({
    required this.deckId,
    required this.title,
    required this.reviews,
    required this.remembered,
    required this.accuracy,
  });

  final String deckId;
  final String title;
  final int reviews;
  final int remembered;
  final int accuracy; // 0–100

  factory DeckAccuracy.fromJson(Map<String, dynamic> json) {
    return DeckAccuracy(
      deckId: json['deckId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled deck',
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      remembered: (json['remembered'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Flashcard review history shown on the Progress screen.
class FlashcardProgress {
  const FlashcardProgress({
    required this.totalReviews,
    required this.uniqueCards,
    required this.decks,
  });

  final int totalReviews;
  final int uniqueCards;
  final List<DeckAccuracy> decks;

  factory FlashcardProgress.fromJson(Map<String, dynamic> json) {
    final decks = json['decks'];
    return FlashcardProgress(
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      uniqueCards: (json['uniqueCards'] as num?)?.toInt() ?? 0,
      decks: decks is List
          ? [
              for (final d in decks)
                if (d is Map) DeckAccuracy.fromJson(Map<String, dynamic>.from(d)),
            ]
          : const [],
    );
  }
}

/// A generated flashcard deck, matching the backend `GET/POST /api/flashcards`
/// payload. `cardCount` is the number of cards the server persisted.
class FlashcardDeck {
  const FlashcardDeck({
    required this.id,
    required this.title,
    required this.cardCount,
    this.notebookId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int cardCount;
  final String? notebookId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    return FlashcardDeck(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled deck',
      cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
      notebookId: json['notebookId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// One card in a deck (from `GET /api/flashcards/[deckId]`).
class Flashcard {
  const Flashcard({required this.id, required this.front, required this.back});

  final String id;
  final String front;
  final String back;

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
    );
  }
}

/// A deck plus its cards — the payload for the study session.
class FlashcardDeckDetail {
  const FlashcardDeckDetail({required this.deck, required this.cards});

  final FlashcardDeck deck;
  final List<Flashcard> cards;
}

/// Review rating: 1 (again) … 5 (easy), matching the backend schema.
enum FlashcardRating {
  again(1, 'Again'),
  hard(3, 'Hard'),
  good(4, 'Good'),
  easy(5, 'Easy');

  const FlashcardRating(this.value, this.label);

  final int value;
  final String label;
}
