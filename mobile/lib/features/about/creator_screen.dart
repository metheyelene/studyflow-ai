import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';

/// Creator screen — Swiss editorial identity.
class CreatorScreen extends StatelessWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? SwissColors.darkBackground : SwissColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SwissSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back, size: 24, color: fg),
                onPressed: () => context.popOrHome(),
              ),

              const SizedBox(height: SwissSpacing.xxxl),

              // StudyFlow mark
              Container(
                width: 80,
                height: 80,
                color: fg,
                alignment: Alignment.center,
                child: Icon(
                  Icons.school,
                  size: 40,
                  color: isDark ? SwissColors.darkBackground : SwissColors.white,
                ),
              ),

              const SizedBox(height: SwissSpacing.xxxl),

              // Title
              Text(
                'STUDYFLOW AI',
                style: SwissTypography.headline.copyWith(color: fg),
              ),

              const SizedBox(height: SwissSpacing.md),
              const SwissDivider(),
              const SizedBox(height: SwissSpacing.xxl),

              // Creator info
              const SwissEyebrow(text: 'Created by'),
              const SizedBox(height: SwissSpacing.sm),
              Text(
                'MITHIL VISWAS KASI',
                style: SwissTypography.section.copyWith(color: fg),
              ),

              const SizedBox(height: SwissSpacing.xxxl),

              // Description
              Text(
                'A study tool built for students who want to learn smarter, not harder.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),

              const Spacer(),

              // Footer
              const SwissDivider(),
              const SizedBox(height: SwissSpacing.md),
              Center(
                child: Text(
                  'MADE WITH PURPOSE',
                  style: SwissTypography.label.copyWith(color: mutedFg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
