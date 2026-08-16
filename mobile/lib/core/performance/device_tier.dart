import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detect_stub.dart'
    if (dart.library.io) 'detect_io.dart'
    if (dart.library.js_interop) 'detect_web.dart'
    as detect;

/// Rendering-performance tier. The low tier targets budget devices:
/// BackdropFilter blur radius is reduced (blur is fill-rate/GPU-bound —
/// the most expensive effect in the glass system) and the ambient
/// background is disabled entirely. Tier is auto-detected from CPU
/// concurrency (a coarse but dependency-free proxy), can be pinned at
/// build time with `--dart-define=PERFORMANCE_TIER=low|standard`, and can
/// be forced on by the user from Settings → Appearance → Reduce visual
/// effects.
enum PerformanceTier { standard, low }

/// Pure mapping so the heuristic is unit-testable: ≤4 logical cores is the
/// classic low-end Android line. 0 means "unknown" → standard.
PerformanceTier tierForCores(int cores) =>
    cores > 0 && cores <= 4 ? PerformanceTier.low : PerformanceTier.standard;

/// Best-effort auto-detection: a compile-time override wins, otherwise the
/// platform's CPU concurrency decides.
PerformanceTier detectPerformanceTier() {
  const override = String.fromEnvironment('PERFORMANCE_TIER');
  if (override == 'low') return PerformanceTier.low;
  if (override == 'standard') return PerformanceTier.standard;
  return tierForCores(detect.cpuCount());
}

/// User's "Reduce visual effects" preference, persisted locally so it
/// survives restarts. OFF (default) → follow auto-detection; ON → force
/// the low tier regardless of device (a manual escape hatch when the
/// heuristic misjudges).
class ReduceEffectsController extends Notifier<bool> {
  static const _prefsKey = 'reduce_visual_effects';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (stored != null && stored != state) state = stored;
    } catch (_) {
      // Unreadable storage — default to auto-detection.
    }
  }

  void setEnabled(bool enabled) {
    state = enabled;
    unawaited(_write(enabled));
  }

  Future<void> _write(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
    } catch (_) {
      // Not persisted — non-fatal; the choice still applies this session.
    }
  }
}

final reduceEffectsProvider = NotifierProvider<ReduceEffectsController, bool>(
  ReduceEffectsController.new,
);

/// The effective rendering tier: the manual switch wins; otherwise the
/// device is auto-detected. Watch this wherever rendering cost matters.
final performanceTierProvider = Provider<PerformanceTier>((ref) {
  if (ref.watch(reduceEffectsProvider)) return PerformanceTier.low;
  return detectPerformanceTier();
});
