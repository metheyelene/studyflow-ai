import 'package:flutter/material.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';

/// Creator screen — Bauhaus editorial identity.
class CreatorScreen extends StatelessWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BauhausSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: BauhausSpacing.xxxl),

              // StudyFlow mark
              const BauhausLogoMark(size: 100),

              const SizedBox(height: BauhausSpacing.xxxl),

              // Title
              Text(
                'STUDYFLOW AI',
                style: BauhausTypography.headline,
              ),

              const SizedBox(height: BauhausSpacing.md),
              const BauhausDivider(),
              const SizedBox(height: BauhausSpacing.xxl),

              // Creator info
              const BauhausEyebrow(text: 'Created by'),
              const SizedBox(height: BauhausSpacing.sm),
              Text(
                'MITHIL VISWAS KASI',
                style: BauhausTypography.section,
              ),

              const SizedBox(height: BauhausSpacing.xxxl),

              // Description
              Text(
                'A study tool built for students who want to learn smarter, not harder.',
                style: BauhausTypography.bodyMuted.copyWith(
                  color: BauhausColors.black.withValues(alpha: 0.6),
                ),
              ),

              const Spacer(),

              // Footer
              const BauhausDivider(),
              const SizedBox(height: BauhausSpacing.md),
              Center(
                child: Text(
                  'MADE WITH PURPOSE',
                  style: BauhausTypography.label.copyWith(
                    color: BauhausColors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
