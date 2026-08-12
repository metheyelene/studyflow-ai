import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../dashboard/dashboard_controller.dart';
import '../flashcards/flashcard_models.dart';
import '../notebooks/notebooks_controller.dart';
import 'flashcard_progress.dart';

/// Progress tab — live stats only (notebooks, sources, AI actions used),
/// plus real flashcard review history (cards reviewed, per-deck accuracy).
/// Learning insights (quiz trends, weak topics) render as an honest state
/// until there is real study history to show.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final notebooks = ref.watch(notebooksControllerProvider).valueOrNull ?? const [];
    final dashboard = ref.watch(dashboardControllerProvider).valueOrNull;
    final sourceCount = notebooks.fold<int>(0, (sum, n) => sum + n.sourceCount);
    final aiUsed = dashboard?.usage.used;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, AppSpacing.xl, 20, context.isPhone ? 120 : 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Your study activity, honestly measured.',
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.library_books_outlined,
                        label: 'Notebooks',
                        value: '${notebooks.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.description_outlined,
                        label: 'Sources',
                        value: '$sourceCount',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.auto_awesome,
                        label: 'AI actions',
                        value: aiUsed == null ? '—' : '$aiUsed',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'FLASHCARD REVIEWS'),
                const SizedBox(height: 10),
                _FlashcardProgressSection(
                  progress: ref.watch(flashcardProgressControllerProvider),
                  onRetry: () => ref.read(flashcardProgressControllerProvider.notifier).refresh(),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(title: 'LEARNING INSIGHTS'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Icon(
                        Icons.insights_outlined,
                        size: 26,
                        color: g.textMuted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your insights appear as you study',
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quiz trends, weakest topics, and review recommendations '
                        'build up from real study history — nothing is invented.',
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(color: g.textMuted, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      GlassButton(
                        label: notebooks.isEmpty ? 'Create a notebook' : 'Open notebooks',
                        icon: Icons.library_books_outlined,
                        onPressed: () => context.go(AppRoutes.notebooks),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: g.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: g.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.small.copyWith(color: g.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppText.eyebrow.copyWith(color: context.glass.textMuted),
    );
  }
}

/// Flashcard review history from the backend: totals + per-deck accuracy.
/// Renders an honest empty state until real reviews exist.
class _FlashcardProgressSection extends StatelessWidget {
  const _FlashcardProgressSection({required this.progress, required this.onRetry});

  final AsyncValue<FlashcardProgress> progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return progress.when(
      loading: () => const GlassSkeleton(height: 96, radius: 20),
      error: (err, _) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: g.danger),
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
      ),
      data: (p) {
        if (p.totalReviews == 0) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.style_outlined, size: 22, color: g.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No flashcard reviews yet. Review a deck and your accuracy history will appear here.',
                      style: AppText.small.copyWith(color: g.textMuted, height: 1.4),
                    ),
                  ),
                  GlassButton(
                    label: 'Review',
                    icon: Icons.style_outlined,
                    variant: GlassButtonVariant.glass,
                    size: GlassButtonSize.small,
                    onPressed: () => context.go(AppRoutes.flashcards),
                  ),
                ],
              ),
            ),
          );
        }
        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.style_outlined, size: 20, color: g.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cards reviewed',
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${p.totalReviews}',
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    '${p.uniqueCards} card${p.uniqueCards == 1 ? '' : 's'} · accuracy from your review history',
                    style: AppText.small.copyWith(color: g.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                for (final deck in p.decks) ...[_DeckAccuracyRow(deck: deck), const SizedBox(height: 10)],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeckAccuracyRow extends StatelessWidget {
  const _DeckAccuracyRow({required this.deck});

  final DeckAccuracy deck;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                deck.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: g.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${deck.accuracy}%',
              style: TextStyle(color: g.primary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              '· ${deck.reviews} rev${deck.reviews == 1 ? '' : 's'}',
              style: AppText.small.copyWith(color: g.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: deck.reviews == 0 ? 0 : deck.accuracy / 100,
            minHeight: 5,
            backgroundColor: g.surfaceSubtle,
            color: g.primary,
          ),
        ),
      ],
    );
  }
}
