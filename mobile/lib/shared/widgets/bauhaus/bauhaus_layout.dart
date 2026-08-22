// ─────────────────────────────────────────────────────────────────────
// BAUHAUS LAYOUT — StudyFlow AI
//
// Section headings, dividers, and layout primitives.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';

/// Section heading with thick black divider line.
class BauhausSectionHeading extends StatelessWidget {
  const BauhausSectionHeading({
    super.key,
    required this.title,
    this.color = BauhausColors.black,
    this.showDivider = true,
  });

  final String title;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: BauhausTypography.label.copyWith(
            color: color,
            letterSpacing: 1.4,
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: BauhausSpacing.xs),
          Container(
            height: BauhausShapes.borderMedium,
            color: BauhausColors.black,
          ),
        ],
      ],
    );
  }
}

/// Thick black divider.
class BauhausDivider extends StatelessWidget {
  const BauhausDivider({
    super.key,
    this.height = BauhausShapes.borderMedium,
    this.color = BauhausColors.black,
    this.margin,
  });

  final double height;
  final Color color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      color: color,
    );
  }
}

/// Hairline divider.
class BauhausHairline extends StatelessWidget {
  const BauhausHairline({
    super.key,
    this.color,
    this.margin,
  });

  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 1,
      color: color ?? BauhausColors.black.withValues(alpha: 0.15),
    );
  }
}

/// Editorial eyebrow label.
class BauhausEyebrow extends StatelessWidget {
  const BauhausEyebrow({
    super.key,
    required this.text,
    this.color = BauhausColors.black,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: BauhausTypography.label.copyWith(
        color: color,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Large display text — hero typography.
class BauhausDisplayText extends StatelessWidget {
  const BauhausDisplayText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: style ?? BauhausTypography.hero,
    );
  }
}
