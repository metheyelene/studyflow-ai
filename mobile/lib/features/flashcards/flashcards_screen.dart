import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import 'flashcards_controller.dart';

/// Flashcards screen — Bauhaus editorial list of decks.
class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(flashcardsControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Flashcards'),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              'STUDY\nSMARTER.',
              style: BauhausTypography.hero.copyWith(fontSize: 36),
            ),
            const SizedBox(height: BauhausSpacing.xl),

            // Content
            Expanded(
              child: asyncState.when(
                loading: () => const BauhausProcessingState(
                  label: 'Loading flashcards',
                ),
                error: (e, _) => BauhausErrorState(
                  title: 'Error',
                  message: 'Could not load your flashcards.',
                  onRetry: () =>
                      ref.read(flashcardsControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (state.decks.isEmpty) {
                    return BauhausEmptyState(
                      title: 'No flashcards',
                      description:
                          'Generate flashcards from your study spaces to start reviewing.',
                      composition: const BauhausComposition(
                        width: 120,
                        height: 120,
                        circleColor: BauhausColors.red,
                        squareColor: BauhausColors.blue,
                        triangleColor: BauhausColors.yellow,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.decks.length,
                    itemBuilder: (context, index) {
                      final deck = state.decks[index];
                      return _DeckCard(
                        deck: deck,
                        onTap: () {
                          // TODO: Navigate to flashcard session
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

/// Flashcard deck card — Bauhaus physical card.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.deck,
    required this.onTap,
  });

  final dynamic deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BauhausSpacing.md),
      child: BauhausCard(
        accent: BauhausCardAccent.circle,
        accentColor: BauhausColors.red,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deck.title.toUpperCase(),
              style: BauhausTypography.section.copyWith(fontSize: 22),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            BauhausLine(height: 2, color: BauhausColors.muted),
            const SizedBox(height: BauhausSpacing.sm),
            BauhausEyebrow(
              text: '${deck.cards?.length ?? 0} cards',
            ),
          ],
        ),
      ),
    );
  }
}
