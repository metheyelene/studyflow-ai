// ─────────────────────────────────────────────────────────────────────
// BAUHAUS STATES — StudyFlow AI
//
// Empty states, error states, success states, and processing graphics.
// All use geometric compositions — no generic icons.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';
import 'bauhaus_primitives.dart';
import 'bauhaus_button.dart';

/// Empty state — geometric composition + action.
class BauhausEmptyState extends StatelessWidget {
  const BauhausEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.composition = const BauhausComposition(width: 160, height: 160),
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget composition;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            composition,
            const SizedBox(height: BauhausSpacing.xxl),
            Text(
              title.toUpperCase(),
              style: BauhausTypography.section,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              description,
              style: BauhausTypography.bodyMuted.copyWith(
                color: BauhausColors.black.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: BauhausSpacing.xl),
              BauhausButton(
                label: actionLabel!,
                variant: BauhausButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state — large black typography + red accent.
class BauhausErrorState extends StatelessWidget {
  const BauhausErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BauhausSquare(size: 64, color: BauhausColors.red),
            const SizedBox(height: BauhausSpacing.xl),
            Text(
              title.toUpperCase(),
              style: BauhausTypography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              message,
              style: BauhausTypography.bodyMuted.copyWith(
                color: BauhausColors.black.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: BauhausSpacing.xl),
              BauhausButton(
                label: 'Try again',
                variant: BauhausButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Success state — geometric lock-in.
class BauhausSuccessState extends StatelessWidget {
  const BauhausSuccessState({
    super.key,
    required this.message,
    this.onContinue,
  });

  final String message;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BauhausLogoMark(size: 80),
            const SizedBox(height: BauhausSpacing.xl),
            Text('READY', style: BauhausTypography.headline),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              message,
              style: BauhausTypography.bodyMuted.copyWith(
                color: BauhausColors.black.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onContinue != null) ...[
              const SizedBox(height: BauhausSpacing.xl),
              BauhausButton(
                label: 'Continue',
                variant: BauhausButtonVariant.primary,
                onPressed: onContinue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Processing state — geometric animation.
class BauhausProcessingState extends StatefulWidget {
  const BauhausProcessingState({super.key, required this.label, this.progress});

  final String label;
  final double? progress;

  @override
  State<BauhausProcessingState> createState() => _BauhausProcessingState();
}

class _BauhausProcessingState extends State<BauhausProcessingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _controller.value * 2 * 3.14159,
                        child: BauhausCircle(
                          size: 40,
                          color: BauhausColors.red,
                        ),
                      ),
                      Transform.rotate(
                        angle: -_controller.value * 2 * 3.14159,
                        child: BauhausSquare(
                          size: 30,
                          color: BauhausColors.blue,
                        ),
                      ),
                      Transform.rotate(
                        angle: _controller.value * 3.14159,
                        child: BauhausTriangle(
                          size: 35,
                          color: BauhausColors.yellow,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: BauhausSpacing.xl),
            Text(widget.label.toUpperCase(), style: BauhausTypography.label),
            if (widget.progress != null) ...[
              const SizedBox(height: BauhausSpacing.md),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: BauhausColors.muted,
                  valueColor: const AlwaysStoppedAnimation(BauhausColors.black),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
