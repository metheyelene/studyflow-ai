/// A generated quiz (list item from `GET /api/quizzes`), with attempt stats.
class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.difficulty,
    this.notebookId,
    this.attempts = 0,
    this.bestScore,
    this.bestTotal,
    required this.createdAt,
  });

  final String id;
  final String title;
  final int questionCount;
  final String difficulty; // "easy" | "medium" | "hard"
  final String? notebookId;
  final int attempts;
  final int? bestScore;
  final int? bestTotal;
  final DateTime createdAt;

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    return QuizSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled quiz',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      difficulty: json['difficulty'] as String? ?? 'medium',
      notebookId: json['notebookId'] as String?,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      bestScore: (json['bestScore'] as num?)?.toInt(),
      bestTotal: (json['bestTotal'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// One multiple-choice question. `correctIndex` and `explanation` are
/// included for self-study: the client shows immediate feedback, while the
/// server re-scores on submission (the stored answers are the truth).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return QuizQuestion(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: opts is List ? opts.map((o) => o.toString()).toList() : const [],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String?,
    );
  }
}

/// A quiz plus its questions — the payload for the take-quiz screen.
class QuizDetail {
  const QuizDetail({required this.quiz, required this.questions});

  final QuizSummary quiz;
  final List<QuizQuestion> questions;
}

/// Per-question feedback from the scoring endpoint.
class QuizAnswerResult {
  const QuizAnswerResult({
    required this.questionId,
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.correct,
    this.explanation,
  });

  final String questionId;
  final String question;
  final List<String> options;
  final int selectedIndex;
  final int correctIndex;
  final bool correct;
  final String? explanation;

  factory QuizAnswerResult.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return QuizAnswerResult(
      questionId: json['questionId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: opts is List ? opts.map((o) => o.toString()).toList() : const [],
      selectedIndex: (json['selectedIndex'] as num?)?.toInt() ?? 0,
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      correct: json['correct'] == true,
      explanation: json['explanation'] as String?,
    );
  }
}

/// The scored result of a completed attempt.
class QuizResult {
  const QuizResult({
    required this.score,
    required this.total,
    required this.percent,
    required this.perQuestion,
  });

  final int score;
  final int total;
  final int percent;
  final List<QuizAnswerResult> perQuestion;

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final list = json['perQuestion'];
    return QuizResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      perQuestion: list is List
          ? [
              for (final q in list)
                if (q is Map) QuizAnswerResult.fromJson(Map<String, dynamic>.from(q)),
            ]
          : const [],
    );
  }
}
