/// StudyFlow AI indicator — a geometric Swiss square that pulses
/// when processing. No glass effects, no gradients.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/swiss_tokens.dart';

const kStudyFlowAiOrb = Key('studyflow-ai-orb');

class StudyFlowAiOrb extends StatefulWidget {
  const StudyFlowAiOrb({super.key, this.size = 22, this.active = false});

  final double size;
  final bool active;

  @override
  State<StudyFlowAiOrb> createState() => _StudyFlowAiOrbState();
}

class _StudyFlowAiOrbState extends State<StudyFlowAiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionDisabled = false;
  bool _depsResolved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_depsResolved && disabled == _motionDisabled) return;
    _depsResolved = true;
    _motionDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant StudyFlowAiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active || _motionDisabled) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final active = widget.active;

    return Semantics(
      label: active ? 'StudyFlow AI is thinking' : 'StudyFlow AI',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _motionDisabled
              ? 0.0
              : Curves.easeInOut.transform(_controller.value);
          final pulse = math.sin(t * math.pi);
          final scale = 1.0 + (active ? 0.15 : 0.03) * pulse;

          return SizedBox(
            key: kStudyFlowAiOrb,
            width: size,
            height: size,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                color: active ? SwissColors.red : SwissColors.black,
              ),
            ),
          );
        },
      ),
    );
  }
}
