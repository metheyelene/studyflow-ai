import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Button hierarchy. Five glass materials, never all equal:
///
///  - [GlassButtonVariant.primary]  — solid accent CTA
///  - [GlassButtonVariant.glossy]   — primary with a stronger specular sheen
///    (hero CTAs, premium, major AI actions)
///  - [GlassButtonVariant.glass]    — glossy utility glass
///  - [GlassButtonVariant.dark]     — deep glossy glass (immersive: media
///    player, audio, AI mode)
///  - [GlassButtonVariant.elevated] — floating elevated control (FAB-style
///    actions, contextual actions)
///  - [GlassButtonVariant.text]     — tertiary, no surface
///
/// Every filled variant is a FULLY GLOSSY 3D material — never frosted. The
/// surface is built from neutral light physics only: a vertical body
/// gradient (light-catching top → deep base), a diagonal specular sheet
/// across the upper third, a crisp top catch-light line, a soft bottom
/// inner shade for curvature, and a controlled outer drop shadow. In
/// monochrome, gloss reads through luminance — the white primary CTA
/// carries the highlight sheet; dark glass carries a faint white sheen.
///
/// Press physics: the button compresses quickly (80ms ease-out), then
/// springs back with a physical overshoot (320ms ease-out-back), and the
/// specular sheet dims while pressed so the light visibly shifts. Primary
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

/// Neutral gloss parameters for one button material. All colors are
/// monochrome — gloss is luminance, never hue.
class _GlossySpec {
  const _GlossySpec({
    required this.bodyTop,
    required this.bodyMid,
    required this.bodyBottom,
    required this.specular,
    required this.edge,
    required this.border,
    required this.shadow,
    required this.shade,
  });

  final Color bodyTop;
  final Color bodyMid;
  final Color bodyBottom;

  /// Peak alpha of the diagonal white specular sheet.
  final double specular;

  /// Peak alpha of the top catch-light line.
  final double edge;

  /// 1px outline color (transparent for borderless CTAs).
  final Color border;

  /// Outer drop-shadow alpha (always black — physical depth, no glow).
  final double shadow;

  /// Bottom inner shade alpha — the 3D base curve.
  final double shade;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPressed = widget.onPressed;
    final disabled = onPressed == null;

    final hasSurface = widget.variant != GlassButtonVariant.text;

    final (fg, spec) = switch (widget.variant) {
      GlassButtonVariant.primary => (
        g.textOnPrimary,
        isDark
            ? const _GlossySpec(
                bodyTop: Color(0xFFFFFFFF),
                bodyMid: Color(0xFFF2F2F2),
                bodyBottom: Color(0xFFCFCFCF),
                specular: 0.42,
                edge: 0.9,
                border: Colors.transparent,
                shadow: 0.32,
                shade: 0.14,
              )
            : const _GlossySpec(
                bodyTop: Color(0xFF5C5C5C),
                bodyMid: Color(0xFF272727),
                bodyBottom: Color(0xFF000000),
                specular: 0.34,
                edge: 0.5,
                border: Colors.transparent,
                shadow: 0.38,
                shade: 0.10,
              ),
      ),
      GlassButtonVariant.glossy => (
        g.textOnPrimary,
        isDark
            ? const _GlossySpec(
                bodyTop: Color(0xFFFFFFFF),
                bodyMid: Color(0xFFF2F2F2),
                bodyBottom: Color(0xFFC9C9C9),
                specular: 0.58,
                edge: 1.0,
                border: Colors.transparent,
                shadow: 0.34,
                shade: 0.16,
              )
            : const _GlossySpec(
                bodyTop: Color(0xFF6A6A6A),
                bodyMid: Color(0xFF2E2E2E),
                bodyBottom: Color(0xFF050505),
                specular: 0.5,
                edge: 0.6,
                border: Colors.transparent,
                shadow: 0.40,
                shade: 0.10,
              ),
      ),
      GlassButtonVariant.glass => (
        g.textPrimary,
        isDark
            ? const _GlossySpec(
                bodyTop: Color(0xFF3C3C3C),
                bodyMid: Color(0xFF242424),
                bodyBottom: Color(0xFF101010),
                specular: 0.26,
                edge: 0.6,
                border: Color(0x1AFFFFFF),
                shadow: 0.24,
                shade: 0.16,
              )
            : const _GlossySpec(
                bodyTop: Color(0xFFFFFFFF),
                bodyMid: Color(0xFFF0F0F0),
                bodyBottom: Color(0xFFDCDCDC),
                specular: 0.42,
                edge: 0.7,
                border: Color(0x1A000000),
                shadow: 0.16,
                shade: 0.10,
              ),
      ),
      GlassButtonVariant.dark => (
        isDark ? g.textPrimary : Colors.white,
        const _GlossySpec(
          bodyTop: Color(0xFF353535),
          bodyMid: Color(0xFF1F1F1F),
          bodyBottom: Color(0xFF0C0C0C),
          specular: 0.24,
          edge: 0.5,
          border: Color(0x1AFFFFFF),
          shadow: 0.30,
          shade: 0.18,
        ),
      ),
      GlassButtonVariant.elevated => (
        g.textPrimary,
        isDark
            ? const _GlossySpec(
                bodyTop: Color(0xFF3F3F3F),
                bodyMid: Color(0xFF272727),
                bodyBottom: Color(0xFF141414),
                specular: 0.24,
                edge: 0.5,
                border: Color(0x1FFFFFFF),
                shadow: 0.34,
                shade: 0.16,
              )
            : const _GlossySpec(
                bodyTop: Color(0xFFFFFFFF),
                bodyMid: Color(0xFFF0F0F0),
                bodyBottom: Color(0xFFDCDCDC),
                specular: 0.42,
                edge: 0.7,
                border: Color(0x1A000000),
                shadow: 0.20,
                shade: 0.10,
              ),
      ),
      GlassButtonVariant.text => (g.primary, null),
    };

    final (height, hPad, font) = switch (widget.size) {
      GlassButtonSize.small => (36.0, 14.0, 13.0),
      GlassButtonSize.medium => (44.0, 18.0, 14.0),
      GlassButtonSize.large => (52.0, 24.0, 15.0),
    };

    // Every filled material casts a soft physical shadow — depth is part
    // of the gloss, and each spec carries its own shadow weight.
    final shadowed = hasSurface;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: fg, weight: 700),
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
    );

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
          curve: _pressed && !disabled ? AppMotion.pressIn : AppMotion.pressOut,
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
                    borderRadius: BorderRadius.circular(AppShapes.button),
                    boxShadow: shadowed && !disabled && !g.reducedEffects
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: spec?.shadow ?? 0.25,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ]
                        : null,
                  ),
                  child: spec == null
                      ? Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPad,
                            vertical: 10,
                          ),
                          child: content,
                        )
                      : _Gloss(
                          spec: spec,
                          // The specular sheet dims while pressed so the
                          // light visibly shifts under the finger.
                          specularAlpha: _pressed && !disabled
                              ? spec.specular * 0.55
                              : spec.specular,
                          height: height,
                          hPad: hPad,
                          child: content,
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

/// The fully glossy 3D glass surface: body gradient, specular sheet, top
/// catch-light, bottom inner shade, and a crisp outline — stacked so the
/// material reads as one polished lens rather than a flat tinted panel.
class _Gloss extends StatelessWidget {
  const _Gloss({
    required this.spec,
    required this.specularAlpha,
    required this.height,
    required this.hPad,
    required this.child,
  });

  final _GlossySpec spec;
  final double specularAlpha;
  final double height;
  final double hPad;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppShapes.button);
    return ClipRRect(
      borderRadius: radius,
      // The content container is the sizing child; the decorative layers
      // are Positioned.fill so the stack works in unbounded-height
      // contexts (rows, intrinsic sizing) without forcing constraints.
      child: Stack(
        fit: StackFit.loose,
        children: [
          // 1. Body — vertical luminance falloff (light-catching top,
          //    deep base) gives the surface its curvature.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [spec.bodyTop, spec.bodyMid, spec.bodyBottom],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          // 2. Specular sheet — a diagonal catch-light across the upper
          //    third, like a soft lamp reflecting off curved glass.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: specularAlpha),
                    Colors.white.withValues(alpha: specularAlpha * 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.22, 0.62],
                ),
              ),
            ),
          ),
          // 3. Bottom inner shade — the 3D base curve turning away from
          //    the light.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: spec.shade),
                  ],
                  stops: const [0.45, 1],
                ),
              ),
            ),
          ),
          // 4. Top catch-light — a crisp bright line along the lip.
          Positioned(
            top: 0,
            left: 7,
            right: 7,
            height: 1.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppShapes.button),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: spec.edge * 0.45),
                    Colors.white.withValues(alpha: spec.edge),
                    Colors.white.withValues(alpha: spec.edge * 0.45),
                  ],
                ),
              ),
            ),
          ),
          // 5. Crisp 1px outline over the gloss.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: spec.border, width: 1),
              ),
            ),
          ),
          // 6. Content — the sizing child.
          Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

enum GlassButtonVariant { primary, glossy, glass, dark, elevated, text }

enum GlassButtonSize { small, medium, large }
