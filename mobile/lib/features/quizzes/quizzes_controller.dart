import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quiz_models.dart';
import 'quizzes_repository.dart';

/// Quiz list state for the Quizzes screen.
class QuizzesState {
  const QuizzesState({required this.quizzes});

  final List<QuizSummary> quizzes;

  QuizzesState copyWith({List<QuizSummary>? quizzes}) {
    return QuizzesState(quizzes: quizzes ?? this.quizzes);
  }
}

class QuizzesController extends AsyncNotifier<QuizzesState> {
  @override
  Future<QuizzesState> build() async {
    final quizzes = await ref.read(quizzesRepositoryProvider).list();
    return QuizzesState(quizzes: quizzes);
  }

  QuizzesRepository get _repo => ref.read(quizzesRepositoryProvider);

  /// Generates a quiz from a notebook and returns it (the caller navigates
  /// to the take-quiz screen). The list is refreshed from the server; a
  /// refresh failure never hides the new quiz.
  Future<QuizDetail> generate(String notebookId, {String difficulty = 'medium'}) async {
    final detail = await _repo.generate(notebookId, difficulty: difficulty);
    try {
      final quizzes = await _repo.list();
      state = AsyncData(QuizzesState(quizzes: [
        detail.quiz,
        ...quizzes.where((q) => q.id != detail.quiz.id),
      ]));
    } catch (_) {
      state = AsyncData(QuizzesState(quizzes: [detail.quiz]));
    }
    return detail;
  }

  Future<void> delete(String quizId) async {
    await _repo.delete(quizId);
    final current = await future;
    state = AsyncData(
      current.copyWith(quizzes: current.quizzes.where((q) => q.id != quizId).toList()),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final quizzes = await _repo.list();
    state = AsyncData(QuizzesState(quizzes: quizzes));
  }
}

final quizzesControllerProvider =
    AsyncNotifierProvider<QuizzesController, QuizzesState>(QuizzesController.new);
