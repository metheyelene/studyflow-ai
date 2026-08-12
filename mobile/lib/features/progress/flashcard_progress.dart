import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../flashcards/flashcard_models.dart';
import '../flashcards/flashcards_repository.dart';

class FlashcardProgressController extends AsyncNotifier<FlashcardProgress> {
  @override
  Future<FlashcardProgress> build() async {
    return ref.read(flashcardsRepositoryProvider).progress();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(flashcardsRepositoryProvider).progress());
  }
}

final flashcardProgressControllerProvider =
    AsyncNotifierProvider<FlashcardProgressController, FlashcardProgress>(
      FlashcardProgressController.new,
    );
