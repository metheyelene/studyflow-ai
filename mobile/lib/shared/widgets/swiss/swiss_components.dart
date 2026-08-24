// ─────────────────────────────────────────────────────────────────────
// SWISS COMPONENTS — Reusable UI primitives for the Swiss International
// design system. Every screen uses these. No duplication.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../core/theme/swiss_tokens.dart';

// ═══════════════════════════════════════════════════════════════════════
// SWISS BUTTON
// ═══════════════════════════════════════════════════════════════════════

enum SwissButtonVariant { primary, secondary, accent, ghost }

class SwissButton extends StatefulWidget {
  const SwissButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = SwissButtonVariant.primary,
    this.onPressed,
    this.fullWidth = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final SwissButtonVariant variant;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool compact;

  @override
  State<SwissButton> createState() => _SwissButtonState();
}

class _SwissButtonState extends State<SwissButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _buttonColors(isDark);
    final height = widget.compact ? 40.0 : 48.0;

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onPressed != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onPressed != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedContainer(
        duration: SwissMotion.fast,
        height: height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? SwissSpacing.md : SwissSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: _pressed ? colors.$2 : colors.$1,
          border: Border.all(color: colors.$3, width: SwissShapes.borderThin),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: colors.$4),
              const SizedBox(width: SwissSpacing.xs),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: SwissTypography.label.copyWith(
                  color: colors.$4,
                  letterSpacing: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns (bg, bgPressed, border, text).
  (Color, Color, Color, Color) _buttonColors(bool isDark) {
    return switch (widget.variant) {
      SwissButtonVariant.primary => (
        isDark ? SwissColors.white : SwissColors.black,
        isDark ? SwissColors.red : SwissColors.red,
        isDark ? SwissColors.white : SwissColors.black,
        isDark ? SwissColors.black : SwissColors.white,
      ),
      SwissButtonVariant.secondary => (
        isDark ? SwissColors.darkSurface : SwissColors.white,
        isDark ? SwissColors.red : SwissColors.red,
        isDark ? SwissColors.darkBorder : SwissColors.black,
        isDark ? SwissColors.darkForeground : SwissColors.black,
      ),
      SwissButtonVariant.accent => (
        SwissColors.red,
        SwissColors.black,
        SwissColors.red,
        SwissColors.white,
      ),
      SwissButtonVariant.ghost => (
        Colors.transparent,
        isDark ? SwissColors.darkMuted : SwissColors.muted,
        Colors.transparent,
        isDark ? SwissColors.white : SwissColors.black,
      ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS CARD
// ═══════════════════════════════════════════════════════════════════════

class SwissCard extends StatelessWidget {
  const SwissCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SwissSpacing.xl),
    this.borderSide,
    this.backgroundColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderSide? borderSide;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        backgroundColor ??
        (isDark ? SwissColors.darkSurface : SwissColors.white);
    final border =
        borderSide ??
        BorderSide(
          color: isDark ? SwissColors.darkBorder : SwissColors.black,
          width: SwissShapes.borderThin,
        );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          border: Border.fromBorderSide(border),
        ),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS SECTION LABEL
// ═══════════════════════════════════════════════════════════════════════

class SwissSectionLabel extends StatelessWidget {
  const SwissSectionLabel({
    super.key,
    required this.number,
    required this.title,
  });

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Row(
      children: [
        Text(
          number,
          style: SwissTypography.label.copyWith(
            color: SwissColors.red,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: SwissSpacing.xs),
        Container(width: 16, height: 1, color: SwissColors.red),
        const SizedBox(width: SwissSpacing.xs),
        Text(
          title.toUpperCase(),
          style: SwissTypography.label.copyWith(color: fg, letterSpacing: 1.5),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS DIVIDER
// ═══════════════════════════════════════════════════════════════════════

class SwissDivider extends StatelessWidget {
  const SwissDivider({super.key, this.thickness = 2, this.color});

  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: thickness,
      color: color ?? (isDark ? SwissColors.darkBorder : SwissColors.black),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS HAIRLINE
// ═══════════════════════════════════════════════════════════════════════

class SwissHairline extends StatelessWidget {
  const SwissHairline({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: 1,
      color: isDark
          ? SwissColors.darkBorder.withValues(alpha: 0.15)
          : SwissColors.black.withValues(alpha: 0.1),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS EYEBROW
// ═══════════════════════════════════════════════════════════════════════

class SwissEyebrow extends StatelessWidget {
  const SwissEyebrow({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: SwissTypography.label.copyWith(
        color: color ?? SwissColors.red,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════

class SwissEmptyState extends StatelessWidget {
  const SwissEmptyState({
    super.key,
    required this.sectionNumber,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String sectionNumber;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionNumber,
            style: SwissTypography.display.copyWith(
              color: SwissColors.red.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: SwissSpacing.lg),
          Text(
            title.toUpperCase(),
            style: SwissTypography.section.copyWith(color: fg),
          ),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            description,
            style: SwissTypography.body.copyWith(color: mutedFg),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SwissSpacing.xl),
            SwissButton(
              label: actionLabel!,
              variant: SwissButtonVariant.primary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS ERROR STATE
// ═══════════════════════════════════════════════════════════════════════

class SwissErrorState extends StatelessWidget {
  const SwissErrorState({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Padding(
      padding: const EdgeInsets.all(SwissSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SwissEyebrow(text: 'Error'),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            title.toUpperCase(),
            style: SwissTypography.section.copyWith(color: fg),
          ),
          const SizedBox(height: SwissSpacing.xs),
          Text(
            message,
            style: SwissTypography.body.copyWith(
              color: isDark
                  ? SwissColors.darkForeground.withValues(alpha: 0.6)
                  : SwissColors.black.withValues(alpha: 0.6),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: SwissSpacing.xl),
            SwissButton(
              label: 'Retry',
              variant: SwissButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS PROCESSING STATE
// ═══════════════════════════════════════════════════════════════════════

class SwissProcessingState extends StatefulWidget {
  const SwissProcessingState({
    super.key,
    required this.label,
    this.steps = const [],
  });

  final String label;
  final List<({String label, bool done})> steps;

  @override
  State<SwissProcessingState> createState() => _SwissProcessingStateState();
}

class _SwissProcessingStateState extends State<SwissProcessingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Padding(
      padding: const EdgeInsets.all(SwissSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SwissEyebrow(text: 'Processing'),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            widget.label.toUpperCase(),
            style: SwissTypography.section.copyWith(color: fg),
          ),
          if (widget.steps.isNotEmpty) ...[
            const SizedBox(height: SwissSpacing.xl),
            for (var i = 0; i < widget.steps.length; i++) ...[
              Row(
                children: [
                  Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: SwissTypography.label.copyWith(
                      color: widget.steps[i].done
                          ? fg
                          : (isDark
                                ? SwissColors.darkForeground.withValues(
                                    alpha: 0.3,
                                  )
                                : SwissColors.black.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: SwissSpacing.md),
                  Expanded(
                    child: Text(
                      widget.steps[i].label.toUpperCase(),
                      style: SwissTypography.body.copyWith(
                        color: widget.steps[i].done
                            ? fg
                            : (isDark
                                  ? SwissColors.darkForeground.withValues(
                                      alpha: 0.3,
                                    )
                                  : SwissColors.black.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  if (widget.steps[i].done)
                    Icon(Icons.check, size: 16, color: fg)
                  else if (i == widget.steps.indexWhere((s) => !s.done))
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (_, _) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: SwissColors.red.withValues(
                            alpha: 0.3 + _animation.value * 0.7,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.circle_outlined,
                      size: 8,
                      color: fg.withValues(alpha: 0.2),
                    ),
                ],
              ),
              if (i < widget.steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: SwissSpacing.xs,
                  ),
                  child: SwissHairline(),
                ),
            ],
          ] else ...[
            const SizedBox(height: SwissSpacing.xl),
            // Animated vertical line with red indicator
            AnimatedBuilder(
              animation: _animation,
              builder: (_, _) => Container(
                height: 4,
                width: double.infinity,
                color: isDark ? SwissColors.darkMuted : SwissColors.muted,
                child: Align(
                  alignment: Alignment(_animation.value * 2 - 1, 0),
                  child: Container(
                    width: 40,
                    height: 4,
                    color: SwissColors.red,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS NUMBERED LIST ITEM
// ═══════════════════════════════════════════════════════════════════════

class SwissNumberedItem extends StatelessWidget {
  const SwissNumberedItem({
    super.key,
    required this.index,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.active = false,
  });

  final int index;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.md),
        child: Row(
          children: [
            // Index number
            SizedBox(
              width: 36,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: SwissTypography.label.copyWith(
                  color: active ? SwissColors.red : mutedFg,
                ),
              ),
            ),
            // Active indicator
            if (active)
              Container(
                width: 3,
                height: 32,
                margin: const EdgeInsets.only(right: SwissSpacing.sm),
                color: SwissColors.red,
              )
            else
              const SizedBox(width: SwissSpacing.sm),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: SwissTypography.subheading.copyWith(
                      color: fg,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: SwissSpacing.xxs),
                    Text(
                      subtitle!,
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                  ],
                ],
              ),
            ),
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS INPUT
// ═══════════════════════════════════════════════════════════════════════

class SwissInput extends StatelessWidget {
  const SwissInput({
    super.key,
    this.controller,
    this.hintText,
    this.label,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? label;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: SwissTypography.label.copyWith(
              color: mutedFg,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: SwissSpacing.xs),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: SwissTypography.body.copyWith(color: fg),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: SwissTypography.body.copyWith(color: mutedFg),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? SwissColors.darkMuted : SwissColors.muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SwissSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: isDark ? SwissColors.darkBorder : SwissColors.black,
                width: SwissShapes.borderThin,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: isDark ? SwissColors.darkBorder : SwissColors.black,
                width: SwissShapes.borderThin,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: SwissColors.red,
                width: SwissShapes.borderThin,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════

class SwissProgressBar extends StatelessWidget {
  const SwissProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.label,
  });

  final double value; // 0.0 to 1.0
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: SwissTypography.caption.copyWith(color: fg)),
          const SizedBox(height: SwissSpacing.xxs),
        ],
        Container(
          width: double.infinity,
          height: height,
          color: isDark ? SwissColors.darkMuted : SwissColors.muted,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: fg),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SWISS SOURCE CITATION
// ═══════════════════════════════════════════════════════════════════════

class SwissCitation extends StatelessWidget {
  const SwissCitation({
    super.key,
    required this.sourceTitle,
    this.page,
    this.excerpt,
    this.onTap,
  });

  final String sourceTitle;
  final int? page;
  final String? excerpt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('citation-chip'),
        width: double.infinity,
        padding: const EdgeInsets.all(SwissSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: SwissColors.red,
              width: SwissShapes.borderMedium,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOURCE',
              style: SwissTypography.label.copyWith(
                color: SwissColors.red,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SwissSpacing.xxs),
            Text(
              '$sourceTitle${page != null ? ' · P.$page' : ''}',
              style: SwissTypography.caption.copyWith(color: fg),
            ),
            if (excerpt != null) ...[
              const SizedBox(height: SwissSpacing.xs),
              Text(
                excerpt!,
                style: SwissTypography.body.copyWith(
                  color: mutedFg,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
