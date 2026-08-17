import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_progress.dart';
import '../dashboard/dashboard_controller.dart';
import '../flashcards/flashcard_models.dart';
import '../notebooks/notebooks_controller.dart';
import 'flashcard_progress.dart';

/// Progress tab — answers one question: "How am I doing?".
///
/// The composition leads with a single primary moment (the mastery hero:
/// a large ring + one recommended next action), supports it with the
/// weakest-topics-first list, and demotes raw counts (notebooks, sources,
/// AI actions) to a quiet metadata line — the old three-stat-card wall is
/// gone. Every number is derived from real study history; with no reviews
/// the screen says so instead of showing fabricated percentages.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final notebooks =
        ref.watch(notebooksControllerProvider).valueOrNull ?? const [];
    final dashboard = ref.watch(dashboardControllerProvider).valueOrNull;
    final sourceCount = notebooks.fold<int>(0, (sum, n) => sum + n.sourceCount);
    final aiUsed = dashboard?.usage.used;
    final progress = ref.watch(flashcardProgressControllerProvider);
    final notebookCount = notebooks.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          AppSpacing.xl,
          20,
          context.isPhone ? 120 : 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'YOUR LEARNING',
                  style: AppText.eyebrow.copyWith(color: g.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  'How am I doing?',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mastery from your real review history — nothing invented.',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                _MasteryHero(
                  progress: progress,
                  onRetry: () => ref
                      .read(flashcardProgressControllerProvider.notifier)
                      .refresh(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _WeakTopics(progress: progress),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '$notebookCount '
                  '${notebookCount == 1 ? 'notebook' : 'notebooks'}'
                  ' · $sourceCount ${sourceCount == 1 ? 'source' : 'sources'}'
                  ' · ${aiUsed ?? '—'} AI actions',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single primary moment: a large mastery ring fed by real review
/// accuracy, one honest subline, and exactly one recommended next action.
class _MasteryHero extends StatelessWidget {
  const _MasteryHero({required this.progress, required this.onRetry});

  final AsyncValue<FlashcardProgress> progress;
  final VoidCallback onRetry;

  /// Weighted average accuracy across decks — real data, never a guess.
  static int? mastery(List<DeckAccuracy> decks, int totalReviews) {
    if (decks.isEmpty || totalReviews <= 0) return null;
    final weight = decks.fold<num>(0, (s, d) => s + d.reviews);
    if (weight <= 0) return null;
    final acc = decks.fold<num>(0, (s, d) => s + d.accuracy * d.reviews);
    return (acc / weight).round();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.floating,
      glossy: true,
      radius: AppShapes.hero,
      child: progress.when(
        loading: () => const Row(
          children: [
            GlassSkeleton(width: 120, height: 120, radius: 60),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSkeleton(width: 120, height: 18),
                  SizedBox(height: 8),
                  GlassSkeleton(width: 180, height: 13),
                  SizedBox(height: 14),
                  GlassSkeleton(width: 140, height: 36, radius: 18),
                ],
              ),
            ),
          ],
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error, size: 20, color: g.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Could not load your flashcard history.',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
        data: (p) {
          final value = mastery(p.decks, p.totalReviews);
          final decks = [...p.decks]
            ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
          final weakest = decks.firstOrNull;
          final deckWord = p.decks.length == 1 ? 'deck' : 'decks';
          final reviewWord = p.totalReviews == 1 ? 'review' : 'reviews';

          final (ctaLabel, ctaIcon, ctaAction) = switch ((value, weakest)) {
            (null, _) => (
              'Review flashcards',
              Icons.style,
              () => context.go(AppRoutes.flashcards),
            ),
            (final int v, final DeckAccuracy w) when w.accuracy < 70 => (
              'Reinforce ${w.title}',
              Icons.replay,
              () => context.go(AppRoutes.flashcards),
            ),
            _ => (
              'Start a quiz',
              Icons.quiz,
              () => context.go(AppRoutes.quizzes),
            ),
          };

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GlassRing(
                  value: value == null ? 0 : value / 100,
                  label: value == null ? '—' : '$value%',
                  size: 120,
                  strokeWidth: 9,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mastery',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value == null
                            ? 'Review a deck and your mastery builds from '
                                  'real accuracy.'
                            : '$value% average accuracy across '
                                  '${p.decks.length} $deckWord'
                                  ' · ${p.totalReviews} $reviewWord',
                        style: AppText.small.copyWith(
                          color: g.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassButton(
                        label: ctaLabel,
                        icon: ctaIcon,
                        size: GlassButtonSize.small,
                        onPressed: ctaAction,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Weakest decks first — the list answers "what should I fix?" with the
/// real accuracy data, banded by how urgent each topic is. Hidden entirely
/// when there is no review history (the hero already explains that state).
class _WeakTopics extends StatelessWidget {
  const _WeakTopics({required this.progress});

  final AsyncValue<FlashcardProgress> progress;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return progress.when(
      loading: () => const GlassSkeleton(height: 120, radius: 20),
      error: (_, _) => const SizedBox.shrink(),
      data: (p) {
        final decks = [...p.decks]
          ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
        if (decks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WEAKEST TOPICS FIRST',
              style: AppText.eyebrow.copyWith(color: g.textMuted),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < decks.length; i++) ...[
              _TopicRow(deck: decks[i]),
              if (i != decks.length - 1)
                Divider(
                  color: g.textPrimary.withValues(alpha: 0.06),
                  height: 1,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.deck});

  final DeckAccuracy deck;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final band = deck.accuracy < 60
        ? g.danger
        : deck.accuracy < 75
        ? g.warning
        : g.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deck.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMedium.copyWith(color: g.textPrimary),
                ),
              ),
              Text(
                '${deck.accuracy}%',
                style: TextStyle(
                  color: band,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${deck.reviews} rev${deck.reviews == 1 ? '' : 's'}',
                style: AppText.small.copyWith(color: g.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: deck.reviews == 0 ? 0 : deck.accuracy / 100,
              minHeight: 5,
              backgroundColor: g.surfaceSubtle,
              color: band,
            ),
          ),
        ],
      ),
    );
  }
}
