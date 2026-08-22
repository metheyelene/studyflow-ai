import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';

/// Premium screen — Swiss poster design.
/// "STUDY WITHOUT LIMITS."
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SwissSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, size: 24, color: fg),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              const SizedBox(height: SwissSpacing.xxl),

              // Section number
              Text(
                '04',
                style: SwissTypography.display.copyWith(
                  color: SwissColors.red.withValues(alpha: 0.2),
                ),
              ),

              const SizedBox(height: SwissSpacing.xl),

              // Hero
              Text(
                'STUDY\nWITHOUT\nLIMITS.',
                style: SwissTypography.display.copyWith(
                  fontSize: 48,
                  color: fg,
                ),
              ),

              const SizedBox(height: SwissSpacing.xxxl),

              // Benefits
              SwissCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SwissEyebrow(text: 'Premium includes'),
                    const SizedBox(height: SwissSpacing.md),
                    _BenefitItem(text: 'AI — unlimited generation'),
                    _BenefitItem(text: 'AUDIO — study podcasts'),
                    _BenefitItem(text: 'FLASHCARDS — unlimited decks'),
                    _BenefitItem(text: 'QUIZZES — unlimited practice'),
                    _BenefitItem(text: 'STUDY — AI-powered planner'),
                  ],
                ),
              ),

              const SizedBox(height: SwissSpacing.xxl),

              // Price
              SwissCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SwissEyebrow(text: 'Founding member'),
                    const SizedBox(height: SwissSpacing.sm),
                    Text(
                      '\$2/month',
                      style: SwissTypography.headline.copyWith(
                        fontSize: 36,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: SwissSpacing.xs),
                    Text(
                      'First 35 members only',
                      style: SwissTypography.body.copyWith(color: mutedFg),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SwissSpacing.xxl),

              // CTA
              SwissButton(
                label: 'Upgrade now',
                variant: SwissButtonVariant.primary,
                fullWidth: true,
                onPressed: () {
                  // TODO: Start checkout
                },
              ),

              const SizedBox(height: SwissSpacing.md),

              // Restore
              SwissButton(
                label: 'Restore purchase',
                variant: SwissButtonVariant.ghost,
                fullWidth: true,
                onPressed: () {
                  // TODO: Restore purchase
                },
              ),

              const SizedBox(height: SwissSpacing.xxl),

              // Terms
              Text(
                'Cancel anytime in Settings. You keep access until the end of your paid period.',
                style: SwissTypography.caption.copyWith(color: mutedFg),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Benefit list item.
class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: SwissSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            color: fg,
          ),
          const SizedBox(width: SwissSpacing.sm),
          Text(
            text.toUpperCase(),
            style: SwissTypography.body.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
