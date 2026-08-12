import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Button hierarchy (web parity): [GlassButtonVariant.primary] solid
/// accent, [GlassButtonVariant.glass] translucent material, and
/// [GlassButtonVariant.text] for tertiary actions — never all equal.
///
/// Subtle press feedback: the whole button scales down ~3% while held
/// (spring-like via [AnimatedScale]), so taps feel physical without
/// bouncing.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.size = GlassButtonSize.medium,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final bool expand;
  final String? semanticLabel;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final onPressed = widget.onPressed;
    final disabled = onPressed == null;

    final (fg, bg, border) = switch (widget.variant) {
      GlassButtonVariant.primary => (
        g.textOnPrimary,
        g.primary,
        Colors.transparent,
      ),
      GlassButtonVariant.glass => (g.textPrimary, g.surface, g.border),
      GlassButtonVariant.text => (
        g.primary,
        Colors.transparent,
        Colors.transparent,
      ),
    };

    final (height, hPad, font) = switch (widget.size) {
      GlassButtonSize.small => (36.0, 14.0, 13.0),
      GlassButtonSize.medium => (44.0, 18.0, 14.0),
      GlassButtonSize.large => (52.0, 24.0, 15.0),
    };

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: AnimatedScale(
          scale: _pressed && !disabled ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Listener(
              // Keep the press feel even when the button is triggered
              // from elsewhere (e.g. keyboard submit).
              onPointerDown: disabled
                  ? null
                  : (_) => setState(() => _pressed = true),
              onPointerUp: disabled
                  ? null
                  : (_) => setState(() => _pressed = false),
              onPointerCancel: disabled
                  ? null
                  : (_) => setState(() => _pressed = false),
              child: InkWell(
                onTap: disabled ? null : onPressed,
                borderRadius: BorderRadius.circular(14),
                splashColor: g.primary.withValues(alpha: 0.12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    boxShadow:
                        widget.variant == GlassButtonVariant.primary &&
                            !disabled
                        ? [
                            BoxShadow(
                              color: g.primary.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    constraints: widget.expand
                        ? const BoxConstraints(minWidth: double.infinity)
                        : null,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: widget.expand
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: fg),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: font,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum GlassButtonVariant { primary, glass, text }

enum GlassButtonSize { small, medium, large }
