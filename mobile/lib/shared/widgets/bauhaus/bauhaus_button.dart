// ─────────────────────────────────────────────────────────────────────
// BAUHAUS BUTTON — StudyFlow AI
//
// Physical, geometric buttons with hard shadows and press interaction.
// Variants: primary (red), secondary (blue), accent (yellow), outline.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';

enum BauhausButtonVariant { primary, secondary, accent, outline, ghost }

enum BauhausButtonSize { small, medium, large }

class BauhausButton extends StatefulWidget {
  const BauhausButton({
    super.key,
    required this.label,
    this.variant = BauhausButtonVariant.primary,
    this.size = BauhausButtonSize.medium,
    this.icon,
    this.onPressed,
    this.expand = false,
  });

  final String label;
  final BauhausButtonVariant variant;
  final BauhausButtonSize size;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  State<BauhausButton> createState() => _BauhausButtonState();
}

class _BauhausButtonState extends State<BauhausButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _pressAnimation = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _pressed = true);
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    _pressController.reverse();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();
    final padding = _padding();
    final textStyle = _textStyle();

    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, child) {
          final offset = _pressAnimation.value;
          return Transform.translate(
            offset: Offset(offset, offset),
            child: Container(
              width: widget.expand ? double.infinity : null,
              padding: padding,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(
                  color: border,
                  width: BauhausShapes.borderMedium,
                ),
                boxShadow: _pressed
                    ? BauhausShadows.none
                    : [
                        BoxShadow(
                          color: BauhausColors.black,
                          offset: Offset(6 - offset, 6 - offset),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: widget.expand
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label.toUpperCase(),
                    style: textStyle.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  (Color bg, Color fg, Color border) _colors() {
    return switch (widget.variant) {
      BauhausButtonVariant.primary => (
        BauhausColors.red,
        BauhausColors.white,
        BauhausColors.black,
      ),
      BauhausButtonVariant.secondary => (
        BauhausColors.blue,
        BauhausColors.white,
        BauhausColors.black,
      ),
      BauhausButtonVariant.accent => (
        BauhausColors.yellow,
        BauhausColors.black,
        BauhausColors.black,
      ),
      BauhausButtonVariant.outline => (
        BauhausColors.white,
        BauhausColors.black,
        BauhausColors.black,
      ),
      BauhausButtonVariant.ghost => (
        Colors.transparent,
        BauhausColors.black,
        Colors.transparent,
      ),
    };
  }

  EdgeInsets _padding() {
    return switch (widget.size) {
      BauhausButtonSize.small => const EdgeInsets.symmetric(
        horizontal: BauhausSpacing.md,
        vertical: BauhausSpacing.xs,
      ),
      BauhausButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: BauhausSpacing.xl,
        vertical: BauhausSpacing.sm,
      ),
      BauhausButtonSize.large => const EdgeInsets.symmetric(
        horizontal: BauhausSpacing.xxl,
        vertical: BauhausSpacing.md,
      ),
    };
  }

  TextStyle _textStyle() {
    return switch (widget.size) {
      BauhausButtonSize.small => BauhausTypography.label.copyWith(fontSize: 11),
      BauhausButtonSize.medium => BauhausTypography.label,
      BauhausButtonSize.large => BauhausTypography.label.copyWith(fontSize: 14),
    };
  }
}
