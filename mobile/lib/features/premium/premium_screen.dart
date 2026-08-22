import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';

/// Premium screen — Bauhaus poster design.
/// "STUDY WITHOUT LIMITS."
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BauhausColors.yellow,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BauhausSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              const SizedBox(height: BauhausSpacing.xxl),

              // Hero
              Text(
                'STUDY\nWITHOUT\nLIMITS.',
                style: BauhausTypography.heroWhite.copyWith(
                  fontSize: 48,
                  color: BauhausColors.black,
                ),
              ),

              const SizedBox(height: BauhausSpacing.xxxl),

              // Geometric composition
              const BauhausComposition(
                width: 240,
                height: 160,
                circleColor: BauhausColors.red,
                squareColor: BauhausColors.blue,
                triangleColor: BauhausColors.black,
              ),

              const SizedBox(height: BauhausSpacing.xxxl),

              // Benefits
              BauhausCard(
                color: BauhausColors.white,
                accent: BauhausCardAccent.circle,
                accentColor: BauhausColors.red,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREMIUM INCLUDES',
                      style: BauhausTypography.label,
                    ),
                    const SizedBox(height: BauhausSpacing.md),
                    _BenefitItem(text: 'AI — unlimited generation'),
                    _BenefitItem(text: 'AUDIO — study podcasts'),
                    _BenefitItem(text: 'FLASHCARDS — unlimited decks'),
                    _BenefitItem(text: 'QUIZZES — unlimited practice'),
                    _BenefitItem(text: 'STUDY — AI-powered planner'),
                  ],
                ),
              ),

              const SizedBox(height: BauhausSpacing.xxl),

              // Price
              BauhausCard(
                color: BauhausColors.white,
                accent: BauhausCardAccent.square,
                accentColor: BauhausColors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOUNDING MEMBER',
                      style: BauhausTypography.label,
                    ),
                    const SizedBox(height: BauhausSpacing.sm),
                    Text(
                      '\$2/month',
                      style: BauhausTypography.headline.copyWith(fontSize: 36),
                    ),
                    const SizedBox(height: BauhausSpacing.xs),
                    Text(
                      'First 35 members only',
                      style: BauhausTypography.bodyMuted.copyWith(
                        color: BauhausColors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: BauhausSpacing.xxl),

              // CTA
              BauhausButton(
                label: 'Upgrade now',
                variant: BauhausButtonVariant.primary,
                size: BauhausButtonSize.large,
                expand: true,
                onPressed: () {
                  // TODO: Start checkout
                },
              ),

              const SizedBox(height: BauhausSpacing.md),

              // Restore
              Center(
                child: BauhausButton(
                  label: 'Restore purchase',
                  variant: BauhausButtonVariant.ghost,
                  onPressed: () {
                    // TODO: Restore purchase
                  },
                ),
              ),

              const SizedBox(height: BauhausSpacing.xxl),

              // Terms
              Text(
                'Cancel anytime in Settings. You keep access until the end of your paid period.',
                style: BauhausTypography.caption.copyWith(
                  color: BauhausColors.black.withValues(alpha: 0.5),
                ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: BauhausSpacing.sm),
      child: Row(
        children: [
          const BauhausSquare(
            size: 8,
            color: BauhausColors.black,
          ),
          const SizedBox(width: BauhausSpacing.sm),
          Text(
            text.toUpperCase(),
            style: BauhausTypography.body,
          ),
        ],
      ),
    );
  }
}
