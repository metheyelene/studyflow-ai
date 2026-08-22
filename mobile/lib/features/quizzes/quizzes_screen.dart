import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'quizzes_controller.dart';

/// Quizzes screen — Swiss editorial list of quizzes.
class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(quizzesControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              onPressed: () => context.popOrHome(),
              tooltip: 'Back',
            ),
            const SizedBox(height: SwissSpacing.lg),

            const SwissEyebrow(text: 'Quizzes'),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'TEST\nYOUR\nKNOWLEDGE.',
              style: SwissTypography.display.copyWith(fontSize: 32),
            ),
            const SizedBox(height: SwissSpacing.xl),
            Expanded(
              child: asyncState.when(
                loading: () => const SwissProcessingState(
                  label: 'Loading quizzes',
                ),
                error: (e, _) => SwissErrorState(
                  title: 'Error',
                  message: 'Could not load your quizzes.',
                  onRetry: () =>
                      ref.read(quizzesControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (state.quizzes.isEmpty) {
                    return SwissEmptyState(
                      sectionNumber: '01',
                      title: 'No quizzes',
                      description:
                          'Generate quizzes from your study spaces to start practicing.',
                    );
                  }
                  return ListView.builder(
                    itemCount: state.quizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = state.quizzes[index];
                      return Column(
                        children: [
                          SwissNumberedItem(
                            index: index + 1,
                            title: quiz.title,
                            subtitle:
                                '${quiz.questionCount} questions · ${quiz.difficulty.toUpperCase()}',
                            onTap: () => context.push(AppRoutes.quizDetail.replaceFirst(':quizId', quiz.id)),
                          ),
                          const SwissHairline(),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
