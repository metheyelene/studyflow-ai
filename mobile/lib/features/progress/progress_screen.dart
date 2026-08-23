import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../dashboard/dashboard_controller.dart';
import '../notebooks/notebooks_controller.dart';
import 'flashcard_progress.dart';

/// Progress tab — Swiss editorial.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final notebooks =
        ref.watch(notebooksControllerProvider).valueOrNull ?? const [];
    final dashboard = ref.watch(dashboardControllerProvider).valueOrNull;
    final sourceCount = notebooks.fold<int>(0, (sum, n) => sum + n.sourceCount);
    final aiUsed = dashboard?.usage.used;
    final progress = ref.watch(flashcardProgressControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SwissEyebrow(text: 'Progress'),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'YOUR LEARNING',
              style: SwissTypography.display.copyWith(fontSize: 36, color: fg),
            ),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'Mastery from your real review history — nothing invented.',
              style: SwissTypography.body.copyWith(color: mutedFg),
            ),
            const SizedBox(height: SwissSpacing.xxl),
            // Mastery hero
            progress.when(
              loading: () => const SwissProcessingState(label: 'Loading'),
              error: (_, _) => SwissErrorState(
                title: 'Error',
                message: 'Could not load flashcard history.',
                onRetry: () =>
                    ref.invalidate(flashcardProgressControllerProvider),
              ),
              data: (p) {
                final decks = [...p.decks]
                  ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
                final weakest = decks.firstOrNull;
                final value = (p.decks.isNotEmpty && p.totalReviews > 0)
                    ? (p.decks.fold<num>(
                                0,
                                (s, d) => s + d.accuracy * d.reviews,
                              ) /
                              p.totalReviews)
                          .round()
                    : null;
                return SwissCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${value ?? "—"}%',
                            style: SwissTypography.display.copyWith(
                              fontSize: 48,
                              color: fg,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MASTERED',
                                  style: SwissTypography.label.copyWith(
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  value == null
                                      ? 'Review a deck to build mastery.'
                                      : '$value% average across ${p.decks.length} decks',
                                  style: SwissTypography.body.copyWith(
                                    color: mutedFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwissProgressBar(value: (value ?? 0) / 100),
                      if (weakest != null && weakest.accuracy < 70) ...[
                        const SizedBox(height: 12),
                        SwissButton(
                          label: 'Reinforce ${weakest.title}',
                          variant: SwissButtonVariant.secondary,
                          onPressed: () => context.go(AppRoutes.flashcards),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: SwissSpacing.xxl),
            // Weak topics
            const SwissSectionLabel(number: '02', title: 'Weakest topics'),
            const SizedBox(height: SwissSpacing.md),
            progress.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (p) {
                final decks = [...p.decks]
                  ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
                if (decks.isEmpty) {
                  return Text(
                    'No review data yet.',
                    style: SwissTypography.body.copyWith(color: mutedFg),
                  );
                }
                return Column(
                  children: [
                    for (final d in decks) ...[
                      SwissNumberedItem(
                        index: d.accuracy,
                        title: d.title,
                        subtitle: '${d.reviews} reviews',
                      ),
                      const SwissHairline(),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: SwissSpacing.xxl),
            Text(
              '$sourceCount sources · ${aiUsed ?? "—"} AI actions',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
          ],
        ),
      ),
    );
  }
}
