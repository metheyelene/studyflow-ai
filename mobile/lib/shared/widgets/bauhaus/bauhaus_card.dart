// ─────────────────────────────────────────────────────────────────────
// BAUHAUS CARD — StudyFlow AI
//
// Physical cards with hard shadows, thick borders, and geometric accents.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';
import 'bauhaus_primitives.dart';

enum BauhausCardAccent { none, circle, square, triangle }

class BauhausCard extends StatefulWidget {
  const BauhausCard({
    super.key,
    required this.child,
    this.color = BauhausColors.white,
    this.borderColor = BauhausColors.black,
    this.borderWidth = BauhausShapes.borderMedium,
    this.accent = BauhausCardAccent.none,
    this.accentColor = BauhausColors.red,
    this.shadow = BauhausShadows.medium,
    this.padding = const EdgeInsets.all(BauhausSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final BauhausCardAccent accent;
  final Color accentColor;
  final List<BoxShadow> shadow;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  State<BauhausCard> createState() => _BauhausCardState();
}

class _BauhausCardState extends State<BauhausCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.onTap != null
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.onTap != null
          ? (_) => setState(() => _hovered = false)
          : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: BauhausMotion.fast,
          curve: BauhausMotion.standard,
          transform: _hovered
              ? (Matrix4.identity()..translateByDouble(0, -3, 0, 1))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.color,
            border: Border.all(
              color: widget.borderColor,
              width: widget.borderWidth,
            ),
            boxShadow: widget.shadow,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(padding: widget.padding, child: widget.child),
              if (widget.accent != BauhausCardAccent.none)
                Positioned(top: 12, right: 12, child: _accentWidget()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accentWidget() {
    return switch (widget.accent) {
      BauhausCardAccent.circle => BauhausCircle(
        size: 12,
        color: widget.accentColor,
      ),
      BauhausCardAccent.square => BauhausSquare(
        size: 12,
        color: widget.accentColor,
      ),
      BauhausCardAccent.triangle => BauhausTriangle(
        size: 12,
        color: widget.accentColor,
      ),
      BauhausCardAccent.none => const SizedBox.shrink(),
    };
  }
}
