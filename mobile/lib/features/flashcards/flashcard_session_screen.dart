import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'flashcard_models.dart';
import 'flashcards_repository.dart';

/// Swiss flashcard session — rectangular cards, no glass.
class FlashcardSessionScreen extends ConsumerWidget {
  const FlashcardSessionScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(flashcardsRepositoryProvider);

    return FutureBuilder<FlashcardDeckDetail>(
      future: repo.deck(deckId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SessionScaffold(
            title: 'Loading deck…',
            child: const Center(
              child: SwissProcessingState(label: 'Loading'),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SessionScaffold(
            title: 'Flashcards',
            child: SwissErrorState(
              title: 'Error',
              message: 'Could not load this deck.',
              onRetry: () => context.popOrHome(),
            ),
          );
        }
        return _SessionScaffold(
          title: snapshot.data!.deck.title,
          child: _SessionBody(detail: snapshot.data!),
        );
      },
    );
  }
}

class _SessionScaffold extends StatelessWidget {
  const _SessionScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.popOrHome(),
                    icon: Icon(Icons.arrow_back, color: fg),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SwissEyebrow(text: 'Study session'),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwissTypography.subheading.copyWith(color: fg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SessionBody extends ConsumerStatefulWidget {
  const _SessionBody({required this.detail});

  final FlashcardDeckDetail detail;

  @override
  ConsumerState<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends ConsumerState<_SessionBody> {
  int _index = 0;
  bool _flipped = false;
  final List<int> _ratings = [];

  FlashcardDeckDetail get detail => widget.detail;
  int get _total => detail.cards.length;
  bool get _done => _index >= _total;

  void _flip() => setState(() => _flipped = !_flipped);

  void _rate(FlashcardRating rating) {
    final card = detail.cards[_index];
    _ratings.add(rating.value);
    ref
        .read(flashcardsRepositoryProvider)
        .review(detail.deck.id, cardId: card.id, rating: rating.value)
        .catchError((_) {});
    setState(() {
      _index++;
      _flipped = false;
    });
  }

  void _restart() => setState(() {
    _index = 0;
    _flipped = false;
    _ratings.clear();
  });

  @override
  Widget build(BuildContext context) {
    if (_total == 0) return const _EmptyDeck();
    if (_done) {
      return _Summary(total: _total, ratings: _ratings, onReplay: _restart);
    }

    final card = detail.cards[_index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final progress = _index / _total;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: Row(
            children: [
              Text(
                'Card ${_index + 1} of $_total',
                style: SwissTypography.label.copyWith(color: fg),
              ),
              const Spacer(),
              Text(
                _flipped ? 'ANSWER' : 'QUESTION',
                style: SwissTypography.label.copyWith(
                  color: _flipped ? SwissColors.red : mutedFg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SwissProgressBar(value: progress),
        ),
        // Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: GestureDetector(
              onTap: _flip,
              child: SwissCard(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwissEyebrow(
                          text: _flipped ? 'Answer' : 'Question',
                          color: _flipped ? SwissColors.red : mutedFg,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _flipped ? card.back : card.front,
                          textAlign: TextAlign.center,
                          style: SwissTypography.subheading.copyWith(
                            color: fg,
                            fontSize: 21,
                          ),
                        ),
                        if (!_flipped) ...[
                          const SizedBox(height: 28),
                          Text(
                            'Tap to reveal the answer',
                            style: SwissTypography.caption.copyWith(
                              color: mutedFg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Rating buttons
        AnimatedOpacity(
          duration: SwissMotion.fast,
          opacity: _flipped ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_flipped,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How well did you know it?',
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final r in FlashcardRating.values) ...[
                        if (r != FlashcardRating.values.first)
                          const SizedBox(width: 8),
                        Expanded(
                          child: SwissButton(
                            label: r.label,
                            variant: r == FlashcardRating.again
                                ? SwissButtonVariant.secondary
                                : SwissButtonVariant.primary,
                            compact: true,
                            onPressed: () => _rate(r),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SwissEmptyState(
        sectionNumber: '01',
        title: 'This deck is empty',
        description: 'Delete it and generate a new one from a notebook with sources.',
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.ratings,
    required this.onReplay,
  });

  final int total;
  final List<int> ratings;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final again = ratings.where((r) => r == 1).length;
    final good = ratings.where((r) => r >= 3 && r < 5).length;
    final easy = ratings.where((r) => r == 5).length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SwissCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SESSION COMPLETE',
                style: SwissTypography.section.copyWith(color: fg),
              ),
              const SizedBox(height: 12),
              Text(
                'You reviewed $total card${total == 1 ? '' : 's'}.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _SummaryStat(label: 'EASY', value: easy, color: fg),
                  _SummaryStat(label: 'GOOD', value: good, color: fg),
                  _SummaryStat(label: 'AGAIN', value: again, color: SwissColors.red),
                ],
              ),
              const SizedBox(height: 22),
              SwissButton(
                label: 'Study again',
                icon: Icons.refresh,
                variant: SwissButtonVariant.secondary,
                fullWidth: true,
                onPressed: onReplay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: SwissTypography.headline.copyWith(
              fontSize: 24,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: SwissTypography.label.copyWith(color: SwissColors.red),
          ),
        ],
      ),
    );
  }
}
