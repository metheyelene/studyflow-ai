/// The StudyFlow AI orb — a small liquid-glass sphere that is the visual
/// signature of the assistant. It breathes gently when idle and pulses
/// with an expanding halo while processing, both in the purpose-coded
/// cyan `ai` accent. It is decorative by design: the surrounding surface
/// carries the semantic text ("Reading your sources…"), so the orb
/// excludes itself from the semantics tree.
///
/// Motion policy:
/// - Reduced motion (`MediaQuery.disableAnimationsOf`): the controller is
///   stopped and the orb renders its settled resting state — a still
///   sphere, no halo, no glow animation.
/// - Low performance tier (`GlassTheme.reducedEffects`): the gradient
///   glow and halo are dropped for a flat filled core (the tiny pulse
///   stays — it is one cheap transform, not a shader pass).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Root of the orb (for tests and semantics exclusion).
const kStudyFlowAiOrb = Key('studyflow-ai-orb');

/// The expanding halo ring, present only while [StudyFlowAiOrb.active] and
/// motion is enabled.
const kStudyFlowAiOrbHalo = Key('studyflow-ai-orb-halo');

/// The scaled core sphere (tests read the pulse from its transform).
const kStudyFlowAiOrbCore = Key('studyflow-ai-orb-core');

/// A small animated StudyFlow AI orb. Pass [active] = true while the
/// assistant is processing (it pulses with a fading halo); leave it false
/// for the calm idle breathing state.
class StudyFlowAiOrb extends StatefulWidget {
  const StudyFlowAiOrb({super.key, this.size = 22, this.active = false});

  /// Diameter of the core sphere in logical pixels.
  final double size;

  /// Whether the assistant is currently processing.
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
      duration: _durationFor(widget.active),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery must be read here, never in initState.
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
    // Swap pace: a busy pulse is quicker and stronger than idle breathing.
    _controller.duration = _durationFor(widget.active);
    _controller.forward(from: 0);
  }

  static Duration _durationFor(bool active) => active
      ? const Duration(milliseconds: 1150)
      : const Duration(milliseconds: 2600);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final size = widget.size;
    final active = widget.active;
    final reduced = g.reducedEffects;

    return Semantics(
      label: active ? 'StudyFlow AI is thinking' : 'StudyFlow AI',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(
              _motionDisabled ? 0.0 : _controller.value,
            );
            // One pulse per cycle: 0 → 1 → 0.
            final pulse = math.sin(t * math.pi);
            final coreScale = 1.0 + (active ? 0.10 : 0.03) * pulse;
            final haloOpacity = active ? 0.45 * (1 - pulse) + 0.10 : 0.0;
            final haloScale = 1.0 + 0.35 * pulse;
            final glowOpacity = active
                ? 0.70 + 0.30 * pulse
                : 0.45 + 0.15 * pulse;

            return SizedBox(
              key: kStudyFlowAiOrb,
              width: size * 2.1,
              height: size * 2.1,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft ambient glow behind the sphere.
                    if (!reduced)
                      Opacity(
                        opacity: glowOpacity,
                        child: Container(
                          width: size * 2.0,
                          height: size * 2.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                g.ai.withValues(alpha: 0.30),
                                g.ai.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Expanding halo ring while processing.
                    if (active && !reduced && !_motionDisabled)
                      Transform.scale(
                        key: kStudyFlowAiOrbHalo,
                        scale: haloScale,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: g.ai.withValues(alpha: haloOpacity),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    // The sphere itself, pulsing.
                    Transform.scale(
                      key: kStudyFlowAiOrbCore,
                      scale: coreScale,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: reduced
                              ? null
                              : RadialGradient(
                                  center: const Alignment(-0.35, -0.45),
                                  radius: 1.1,
                                  colors: [
                                    Color.lerp(g.ai, Colors.white, 0.45)!,
                                    g.ai,
                                    Color.lerp(g.ai, Colors.black, 0.35)!,
                                  ],
                                ),
                          color: reduced ? g.ai : null,
                        ),
                      ),
                    ),
                    // Specular lip — a faint top-left reflection so the
                    // sphere reads as a lit glass object, not a flat disc.
                    if (!reduced)
                      Positioned(
                        left: size * 0.14,
                        top: size * 0.10,
                        width: size * 0.34,
                        height: size * 0.18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(size),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
