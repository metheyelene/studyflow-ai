import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import 'flashcard_models.dart';
import 'flashcards_repository.dart';

/// A focused study session for one deck: tap to flip, then rate each card
/// (Again / Hard / Good / Easy). Ratings are sent to the backend as they
/// happen, best-effort, so a partially-completed session still leaves
/// review history.
class FlashcardSessionScreen extends ConsumerWidget {
  const FlashcardSessionScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final repo = ref.watch(flashcardsRepositoryProvider);

    return FutureBuilder<FlashcardDeckDetail>(
      future: repo.deck(deckId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SessionScaffold(
            title: 'Loading deck…',
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SessionScaffold(
            title: 'Flashcards',
            child: Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 26, color: g.textMuted),
                    const SizedBox(height: 12),
                    Text('Could not load this deck', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Back',
                      icon: Icons.arrow_back,
                      variant: GlassButtonVariant.glass,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final detail = snapshot.data!;
        return _SessionScaffold(
          title: detail.deck.title,
          child: _SessionBody(detail: detail),
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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
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
    // Best-effort persistence: a slow network must never block studying.
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
    if (_total == 0) {
      return const _EmptyDeck();
    }
    if (_done) {
      return _Summary(
        total: _total,
        ratings: _ratings,
        onReplay: _restart,
      );
    }

    final card = detail.cards[_index];
    final g = context.glass;
    final progress = _index / _total;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Row(
            children: [
              Text(
                'Card ${_index + 1} of $_total',
                style: TextStyle(
                  color: g.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                _flipped ? 'Answer' : 'Question',
                style: TextStyle(color: g.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: g.border,
              valueColor: AlwaysStoppedAnimation(g.primary),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, context.isPhone ? 16 : 24),
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _CardFace(
                  key: ValueKey('$_index-$_flipped'),
                  text: _flipped ? card.back : card.front,
                  isAnswer: _flipped,
                  hint: _flipped ? null : 'Tap to reveal the answer',
                ),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _flipped ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_flipped,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, context.isPhone ? 20 : 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How well did you know it?',
                    style: TextStyle(color: g.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final r in FlashcardRating.values) ...[
                        if (r != FlashcardRating.values.first) const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            label: r.label,
                            variant: r == FlashcardRating.again
                                ? GlassButtonVariant.glass
                                : GlassButtonVariant.primary,
                            size: GlassButtonSize.small,
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

class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.text,
    required this.isAnswer,
    this.hint,
  });

  final String text;
  final bool isAnswer;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: isAnswer ? GlassTone.floating : GlassTone.surface,
      radius: 28,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAnswer ? 'Answer' : 'Question',
                style: TextStyle(
                  color: isAnswer ? g.primary : g.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 20),
                Text(
                  hint!,
                  style: TextStyle(color: g.textMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text('This deck is empty', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Delete it and generate a new one from a notebook with sources.',
                textAlign: TextAlign.center,
                style: TextStyle(color: g.textMuted, fontSize: 13.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.ratings, required this.onReplay});

  final int total;
  final List<int> ratings;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final again = ratings.where((r) => r == 1).length;
    final good = ratings.where((r) => r >= 3 && r < 5).length;
    final easy = ratings.where((r) => r == 5).length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle_outline, size: 40, color: g.success),
                const SizedBox(height: 12),
                Text(
                  'Session complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'You reviewed $total card${total == 1 ? '' : 's'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _SummaryStat(label: 'Easy', value: easy, color: g.success),
                    _SummaryStat(label: 'Good', value: good, color: g.primary),
                    _SummaryStat(label: 'Again', value: again, color: g.warning),
                  ],
                ),
                const SizedBox(height: 22),
                GlassButton(
                  label: 'Study again',
                  icon: Icons.refresh,
                  variant: GlassButtonVariant.glass,
                  onPressed: onReplay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: g.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
