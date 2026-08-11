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
