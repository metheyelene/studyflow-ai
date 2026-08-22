import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import 'quizzes_controller.dart';

/// Quizzes screen — Bauhaus editorial list of quizzes.
class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(quizzesControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Quizzes'),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              'TEST\nYOUR\nKNOWLEDGE.',
              style: BauhausTypography.hero.copyWith(fontSize: 32),
            ),
            const SizedBox(height: BauhausSpacing.xl),

            // Content
            Expanded(
              child: asyncState.when(
                loading: () => const BauhausProcessingState(
                  label: 'Loading quizzes',
                ),
                error: (e, _) => BauhausErrorState(
                  title: 'Error',
                  message: 'Could not load your quizzes.',
                  onRetry: () =>
                      ref.read(quizzesControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (state.quizzes.isEmpty) {
                    return BauhausEmptyState(
                      title: 'No quizzes',
                      description:
                          'Generate quizzes from your study spaces to start practicing.',
                      composition: const BauhausComposition(
                        width: 120,
                        height: 120,
                        circleColor: BauhausColors.yellow,
                        squareColor: BauhausColors.red,
                        triangleColor: BauhausColors.blue,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.quizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = state.quizzes[index];
                      return _QuizCard(
                        quiz: quiz,
                        onTap: () {
                          // TODO: Navigate to quiz session
                        },
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

/// Quiz card — Bauhaus style.
class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.onTap,
  });

  final dynamic quiz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BauhausSpacing.md),
      child: BauhausCard(
        accent: BauhausCardAccent.square,
        accentColor: BauhausColors.blue,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quiz.title.toUpperCase(),
              style: BauhausTypography.section.copyWith(fontSize: 22),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            BauhausLine(height: 2, color: BauhausColors.muted),
            const SizedBox(height: BauhausSpacing.sm),
            Row(
              children: [
                BauhausEyebrow(
                  text: '${quiz.questionCount} questions',
                ),
                const SizedBox(width: BauhausSpacing.md),
                BauhausEyebrow(
                  text: quiz.difficulty.toUpperCase(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
