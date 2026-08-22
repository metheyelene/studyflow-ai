// ─────────────────────────────────────────────────────────────────────
// BAUHAUS GEOMETRIC PRIMITIVES — StudyFlow AI
//
// Reusable shapes: circles, squares, triangles, lines, compositions.
// All built with Flutter CustomPainter for lightweight rendering.
// ─────────────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/bauhaus_tokens.dart';

/// A geometric circle — the Bauhaus SOURCE shape.
class BauhausCircle extends StatelessWidget {
  const BauhausCircle({
    super.key,
    this.size = 48,
    this.color = BauhausColors.black,
    this.strokeWidth = 0,
    this.borderColor,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: strokeWidth > 0 ? Colors.transparent : color,
        border: strokeWidth > 0
            ? Border.all(
                color: borderColor ?? BauhausColors.black,
                width: strokeWidth,
              )
            : null,
      ),
    );
  }
}

/// A geometric square — the Bauhaus STRUCTURE shape.
class BauhausSquare extends StatelessWidget {
  const BauhausSquare({
    super.key,
    this.size = 48,
    this.color = BauhausColors.black,
    this.strokeWidth = 0,
    this.borderColor,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: strokeWidth > 0 ? Colors.transparent : color,
        border: strokeWidth > 0
            ? Border.all(
                color: borderColor ?? BauhausColors.black,
                width: strokeWidth,
              )
            : null,
      ),
    );
  }
}

/// A geometric triangle — the Bauhaus KNOWLEDGE shape.
class BauhausTriangle extends StatelessWidget {
  const BauhausTriangle({
    super.key,
    this.size = 48,
    this.color = BauhausColors.black,
    this.rotation = 0,
    this.strokeWidth = 0,
    this.borderColor,
  });

  final double size;
  final Color color;
  final double rotation; // in radians
  final double strokeWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrianglePainter(
          color: color,
          strokeWidth: strokeWidth,
          borderColor: borderColor ?? BauhausColors.black,
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({
    required this.color,
    required this.strokeWidth,
    required this.borderColor,
  });

  final Color color;
  final double strokeWidth;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = strokeWidth > 0 ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    if (strokeWidth > 0) {
      paint.color = borderColor;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => false;
}

/// A geometric line — used for dividers and accents.
class BauhausLine extends StatelessWidget {
  const BauhausLine({
    super.key,
    this.height = 4,
    this.color = BauhausColors.black,
    this.width,
  });

  final double height;
  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color,
    );
  }
}

/// A Bauhaus composition — overlapping geometric shapes.
class BauhausComposition extends StatelessWidget {
  const BauhausComposition({
    super.key,
    this.width = 200,
    this.height = 200,
    this.showCircle = true,
    this.showSquare = true,
    this.showTriangle = true,
    this.circleColor = BauhausColors.blue,
    this.squareColor = BauhausColors.yellow,
    this.triangleColor = BauhausColors.red,
  });

  final double width;
  final double height;
  final bool showCircle;
  final bool showSquare;
  final bool showTriangle;
  final Color circleColor;
  final Color squareColor;
  final Color triangleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showCircle)
            Positioned(
              top: height * 0.1,
              left: width * 0.05,
              child: BauhausCircle(
                size: width * 0.55,
                color: circleColor,
              ),
            ),
          if (showSquare)
            Positioned(
              top: height * 0.2,
              right: width * 0.05,
              child: BauhausSquare(
                size: width * 0.45,
                color: squareColor,
              ),
            ),
          if (showTriangle)
            Positioned(
              bottom: height * 0.05,
              left: width * 0.25,
              child: BauhausTriangle(
                size: width * 0.5,
                color: triangleColor,
                rotation: math.pi * 0.1,
              ),
            ),
        ],
      ),
    );
  }
}

/// The StudyFlow geometric logo mark — circle + square + triangle.
class BauhausLogoMark extends StatelessWidget {
  const BauhausLogoMark({
    super.key,
    this.size = 80,
    this.primaryColor = BauhausColors.black,
    this.showBackground = true,
  });

  final double size;
  final Color primaryColor;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showBackground)
            Positioned.fill(
              child: BauhausSquare(
                size: size,
                color: BauhausColors.white,
                strokeWidth: 4,
                borderColor: BauhausColors.black,
              ),
            ),
          Positioned(
            top: size * 0.12,
            left: size * 0.12,
            child: BauhausCircle(
              size: size * 0.35,
              color: BauhausColors.red,
            ),
          ),
          Positioned(
            top: size * 0.15,
            right: size * 0.12,
            child: BauhausSquare(
              size: size * 0.28,
              color: BauhausColors.blue,
            ),
          ),
          Positioned(
            bottom: size * 0.12,
            left: size * 0.2,
            child: BauhausTriangle(
              size: size * 0.38,
              color: BauhausColors.yellow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bauhaus processing spinner — rotating geometric shapes.
class BauhausSpinner extends StatefulWidget {
  const BauhausSpinner({
    super.key,
    this.size = 48,
  });

  final double size;

  @override
  State<BauhausSpinner> createState() => _BauhausSpinnerState();
}

class _BauhausSpinnerState extends State<BauhausSpinner>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: BauhausCircle(
                  size: widget.size * 0.4,
                  color: BauhausColors.red,
                ),
              ),
              Transform.rotate(
                angle: -_controller.value * 2 * math.pi,
                child: BauhausSquare(
                  size: widget.size * 0.3,
                  color: BauhausColors.blue,
                ),
              ),
              Transform.rotate(
                angle: _controller.value * math.pi,
                child: BauhausTriangle(
                  size: widget.size * 0.35,
                  color: BauhausColors.yellow,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
