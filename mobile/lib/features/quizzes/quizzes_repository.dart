import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'quiz_models.dart';

/// Quiz data access. [QuizzesException] carries a user-safe message.
abstract class QuizzesRepository {
  Future<List<QuizSummary>> list();
  Future<QuizDetail> generate(
    String notebookId, {
    String? difficulty,
    int? count,
  });
  Future<QuizDetail> quiz(String quizId);
  Future<void> delete(String quizId);
  Future<QuizResult> submit(String quizId, {required List<int> answers});
}

class ApiQuizzesRepository implements QuizzesRepository {
  ApiQuizzesRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<QuizSummary>> list() async {
    final res = await _client.get<dynamic>('/api/quizzes');
    final data = res.data;
    final list = data is Map ? data['quizzes'] : null;
    if (list is! List) {
      throw const QuizzesException('Could not load your quizzes.');
    }
    return [
      for (final q in list)
        if (q is Map) QuizSummary.fromJson(Map<String, dynamic>.from(q)),
    ];
  }

  @override
  Future<QuizDetail> generate(
    String notebookId, {
    String? difficulty,
    int? count,
  }) async {
    final res = await _client.post<dynamic>(
      '/api/quizzes',
      data: {
        'notebookId': notebookId,
        'difficulty': ?difficulty,
        'count': ?count,
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw const QuizzesException('Could not generate that quiz.');
    }
    final quizJson = data['quiz'];
    final questions = data['questions'];
    if (quizJson is! Map || questions is! List) {
      throw const QuizzesException('Could not generate that quiz.');
    }
    return QuizDetail(
      quiz: QuizSummary.fromJson(Map<String, dynamic>.from(quizJson)),
      questions: [
        for (final q in questions)
          if (q is Map) QuizQuestion.fromJson(Map<String, dynamic>.from(q)),
      ],
    );
  }

  @override
  Future<QuizDetail> quiz(String quizId) async {
    final res = await _client.get<dynamic>('/api/quizzes/$quizId');
    final data = res.data;
    if (data is! Map) throw const QuizzesException('Could not load that quiz.');
    final quizJson = data['quiz'];
    final questions = data['questions'];
    if (quizJson is! Map || questions is! List) {
      throw const QuizzesException('Could not load that quiz.');
    }
    return QuizDetail(
      quiz: QuizSummary.fromJson(Map<String, dynamic>.from(quizJson)),
      questions: [
        for (final q in questions)
          if (q is Map) QuizQuestion.fromJson(Map<String, dynamic>.from(q)),
      ],
    );
  }

  @override
  Future<void> delete(String quizId) =>
      _client.delete<dynamic>('/api/quizzes/$quizId');

  @override
  Future<QuizResult> submit(String quizId, {required List<int> answers}) async {
    final res = await _client.post<dynamic>(
      '/api/quizzes/$quizId/answers',
      data: {'answers': answers},
    );
    final data = res.data;
    if (data is! Map) {
      throw const QuizzesException('Could not score your answers.');
    }
    return QuizResult.fromJson(Map<String, dynamic>.from(data));
  }
}

class QuizzesException implements Exception {
  const QuizzesException(this.message);
  final String message;
}

final quizzesRepositoryProvider = Provider<QuizzesRepository>(
  (ref) => ApiQuizzesRepository(ref.watch(apiClientProvider)),
);
