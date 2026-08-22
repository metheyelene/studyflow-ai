import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'flashcards_controller.dart';

/// Flashcards screen — Swiss editorial list of decks.
class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(flashcardsControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SwissEyebrow(text: 'Flashcards'),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'STUDY\nSMARTER.',
              style: SwissTypography.display.copyWith(fontSize: 36),
            ),
            const SizedBox(height: SwissSpacing.xl),
            Expanded(
              child: asyncState.when(
                loading: () => const SwissProcessingState(
                  label: 'Loading flashcards',
                ),
                error: (e, _) => SwissErrorState(
                  title: 'Error',
                  message: 'Could not load your flashcards.',
                  onRetry: () =>
                      ref.read(flashcardsControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (state.decks.isEmpty) {
                    return SwissEmptyState(
                      sectionNumber: '01',
                      title: 'No flashcards',
                      description:
                          'Generate flashcards from your study spaces to start reviewing.',
                    );
                  }
                  return ListView.builder(
                    itemCount: state.decks.length,
                    itemBuilder: (context, index) {
                      final deck = state.decks[index];
                      return Column(
                        children: [
                          SwissNumberedItem(
                            index: index + 1,
                            title: deck.title,
                            subtitle: '${deck.cardCount} cards',
                            onTap: () {},
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
