import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Button hierarchy. Five glass materials, never all equal:
///
///  - [GlassButtonVariant.primary]  — solid accent CTA
///  - [GlassButtonVariant.glossy]   — primary with a specular sheen (hero
///    CTAs, premium, major AI actions)
///  - [GlassButtonVariant.glass]    — clear/frosted translucent utility
///  - [GlassButtonVariant.dark]     — dark glass (immersive: media player,
///    audio, AI mode)
///  - [GlassButtonVariant.elevated] — floating elevated control (FAB-style
///    actions, contextual actions)
///  - [GlassButtonVariant.text]     — tertiary, no surface
///
/// Press physics: the button compresses quickly (80ms ease-out), then
/// springs back with a physical overshoot (320ms ease-out-back). Primary
/// and glossy variants also give a light haptic tick on activation.
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

  void _activate() {
    // Light tick on meaningful activation; a no-op in tests.
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final onPressed = widget.onPressed;
    final disabled = onPressed == null;

    final filled = switch (widget.variant) {
      GlassButtonVariant.primary ||
      GlassButtonVariant.glossy ||
      GlassButtonVariant.glass ||
      GlassButtonVariant.dark ||
      GlassButtonVariant.elevated => true,
      GlassButtonVariant.text => false,
    };

    final (fg, bg, border) = switch (widget.variant) {
      GlassButtonVariant.primary => (
        g.textOnPrimary,
        g.primary,
        Colors.transparent,
      ),
      GlassButtonVariant.glossy => (
        g.textOnPrimary,
        g.primary,
        Colors.transparent,
      ),
      GlassButtonVariant.glass => (g.textPrimary, g.surface, g.border),
      GlassButtonVariant.dark => (
        Theme.of(context).brightness == Brightness.dark
            ? g.textPrimary
            : Colors.white,
        const Color(0xCC111718),
        g.border,
      ),
      GlassButtonVariant.elevated => (
        g.textPrimary,
        g.floating,
        g.border,
      ),
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

    final glossy = widget.variant == GlassButtonVariant.glossy;
    final shadowed =
        widget.variant == GlassButtonVariant.primary ||
        glossy ||
        widget.variant == GlassButtonVariant.elevated;

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: AnimatedScale(
          // Press: compress fast (ease-out); release: spring back with a
          // physical overshoot. AnimatedScale re-reads curve/duration each
          // build, so the direction is inherently asymmetric.
          scale: _pressed && !disabled ? 0.965 : 1.0,
          duration: _pressed && !disabled
              ? AppMotion.pressInDuration
              : AppMotion.pressOutDuration,
          curve: _pressed && !disabled
              ? AppMotion.pressIn
              : AppMotion.pressOut,
          child: Material(
            color: Colors.transparent,
            child: Listener(
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
                onTap: disabled ? null : _activate,
                borderRadius: BorderRadius.circular(AppShapes.button),
                splashColor: g.primary.withValues(alpha: 0.12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppShapes.button),
                    border: Border.all(color: border),
                    boxShadow: shadowed && !disabled && !g.reducedEffects
                        ? [
                            BoxShadow(
                              color: (widget.variant ==
                                          GlassButtonVariant.elevated
                                      ? Colors.black
                                      : g.primary)
                                  .withValues(
                                    alpha:
                                        widget.variant ==
                                                GlassButtonVariant.elevated
                                            ? 0.18
                                            : 0.25,
                                  ),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ]
                        : null,
                  ),
                  child: DecoratedBox(
                    // Specular sweep across filled materials — a soft
                    // light sheet that makes the button read as glass.
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppShapes.button),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: filled
                            ? [
                                Colors.white.withValues(
                                  alpha: glossy
                                      ? 0.28
                                      : widget.variant ==
                                                GlassButtonVariant.primary
                                            ? 0.18
                                            : widget.variant ==
                                                      GlassButtonVariant.dark
                                                  ? 0.10
                                                  : 0.08,
                                ),
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.03),
                              ]
                            : const [Colors.transparent, Colors.transparent],
                        stops: filled
                            ? const [0, 0.45, 1]
                            : const [0, 1],
                      ),
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
                                letterSpacing: 0.1,
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
      ),
    );
  }
}

enum GlassButtonVariant { primary, glossy, glass, dark, elevated, text }

enum GlassButtonSize { small, medium, large }
