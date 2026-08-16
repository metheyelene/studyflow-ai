import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_progress.dart';
import 'flashcard_models.dart';
import 'flashcards_repository.dart';

/// A focused study session for one deck: tap the large card to flip it with
/// a physical 3D rotation, swipe left/right to rate it, or use the rating
/// buttons. Ratings are sent to the backend as they happen, best-effort, so
/// a partially-completed session still leaves review history.
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
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
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
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 26,
                      color: g.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this deck',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Back',
                      icon: Icons.arrow_back,
                      variant: GlassButtonVariant.glass,
                      onPressed: () => context.popOrHome(),
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
    final g = context.glass;
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
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDY SESSION',
                          style: AppText.eyebrow.copyWith(color: g.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
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
      return _Summary(total: _total, ratings: _ratings, onReplay: _restart);
    }

    final card = detail.cards[_index];
    final g = context.glass;
    final isPhone = context.isPhone;
    final progress = _index / _total;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, isPhone ? 6 : 10, 24, 0),
          child: Row(
            children: [
              Text(
                'Card ${_index + 1} of $_total',
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              // Face state — an eyebrow pill instead of a plain label.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _flipped
                      ? g.primary.withValues(alpha: 0.14)
                      : g.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppShapes.pill),
                ),
                child: Text(
                  _flipped ? 'Answer' : 'Question',
                  style: TextStyle(
                    color: _flipped ? g.primary : g.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isPhone ? 10 : 14),
        // Progress animates from the previous value on every advance.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress),
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            builder: (context, value, _) =>
                GlassProgress(value: value, height: 6),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, isPhone ? 14 : 20, 20, 0),
            child: _StudyCard(
              key: ValueKey(card.id),
              front: card.front,
              back: card.back,
              showAnswer: _flipped,
              onFlip: _flip,
              onRate: _rate,
            ),
          ),
        ),
        // Rating row — the hint explains the swipe affordance.
        AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: _flipped ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_flipped,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                isPhone ? 12 : 20,
                20,
                isPhone ? 16 : 28,
              ),
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
                        if (r != FlashcardRating.values.first)
                          const SizedBox(width: 8),
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
                  const SizedBox(height: 10),
                  Text(
                    'Swipe left for Again · swipe right for Good',
                    style: TextStyle(
                      color: g.textMuted.withValues(alpha: 0.8),
                      fontSize: 11.5,
                    ),
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

/// The large central flashcard: a physical 3D flip on tap and a
/// follow-the-finger swipe that commits a rating (left = Again,
/// right = Good) or springs back. Reduced motion flips instantly and
/// skips the fly-out; the low performance tier drops the gloss.
class _StudyCard extends StatefulWidget {
  const _StudyCard({
    super.key,
    required this.front,
    required this.back,
    required this.showAnswer,
    required this.onFlip,
    required this.onRate,
  });

  final String front;
  final String back;
  final bool showAnswer;
  final VoidCallback onFlip;
  final ValueChanged<FlashcardRating> onRate;

  @override
  State<_StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<_StudyCard> with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );
  late final AnimationController _drag = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );

  double _dx = 0;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    if (widget.showAnswer) {
      _flip.value = 1;
    }
  }

  @override
  void didUpdateWidget(_StudyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAnswer != oldWidget.showAnswer) {
      if (_reduceMotion) {
        _flip.value = widget.showAnswer ? 1 : 0;
      } else {
        _flip.animateTo(widget.showAnswer ? 1 : 0);
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    if (_reduceMotion) return;
    _dx = (_dx + details.delta.dx).clamp(-width, width);
    _drag.value = _dx / width;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_reduceMotion) {
      _dx = 0;
      _drag.value = 0;
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final pastThreshold = _dx.abs() > 90 || velocity.abs() > 600;
    if (!pastThreshold) {
      // Spring back — easeOutBack gives the physical overshoot.
      _dx = 0;
      _drag.animateTo(0, duration: AppMotion.medium, curve: AppMotion.pressOut);
      return;
    }
    final direction = (_dx > 0 || velocity > 0) ? 1 : -1;
    final rating = direction > 0 ? FlashcardRating.good : FlashcardRating.again;
    HapticFeedback.selectionClick();
    _dx = 0;
    _drag
        .animateTo(direction * 1.4, duration: AppMotion.fast)
        .whenComplete(() => widget.onRate(rating));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final reduceMotion = _reduceMotion;
    final width = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onFlip,
      onHorizontalDragUpdate: (d) => _handleDragUpdate(d, width),
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _drag]),
        builder: (context, _) {
          final angle = _flip.value * math.pi;
          final slide = _drag.value * width;
          return Transform.translate(
            offset: Offset(slide, 0),
            child: Transform.rotate(
              angle: _drag.value * 0.09,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Question face.
                  Transform(
                    transformHitTests: false,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle),
                    alignment: Alignment.center,
                    child: _Face(
                      label: 'QUESTION',
                      text: widget.front,
                      isAnswer: false,
                      hint: reduceMotion ? null : 'Tap to reveal the answer',
                      glossy: !g.reducedEffects,
                    ),
                  ),
                  // Answer face — rotated π ahead so it reads correctly.
                  Transform(
                    transformHitTests: false,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle + math.pi),
                    alignment: Alignment.center,
                    child: Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _Face(
                        label: 'ANSWER',
                        text: widget.back,
                        isAnswer: true,
                        glossy: !g.reducedEffects,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.label,
    required this.text,
    required this.isAnswer,
    this.hint,
    required this.glossy,
  });

  final String label;
  final String text;
  final bool isAnswer;
  final String? hint;
  final bool glossy;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isPhone = context.isPhone;
    return GlassCard(
      tone: isAnswer ? GlassTone.floating : GlassTone.surface,
      glossy: glossy,
      radius: AppShapes.hero,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isPhone ? 24 : 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isAnswer ? g.primary : g.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: isPhone ? 16 : 24),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: isPhone ? 21 : 24,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (hint != null) ...[
                SizedBox(height: isPhone ? 20 : 28),
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
              Text(
                'This deck is empty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Delete it and generate a new one from a notebook with sources.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
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
                    _SummaryStat(
                      label: 'Again',
                      value: again,
                      color: g.warning,
                    ),
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
    final g = context.glass;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: g.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
