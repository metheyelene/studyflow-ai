import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/connectivity_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// The app frame around every route (shell tabs AND pushed screens like
/// the study space). Shows a quiet offline strip whenever the network is
/// down; renders as a transparent pass-through otherwise. Local features
/// (flashcard review, progress) are not gated by it — they run as usual
/// and surface their own errors if a request fails.
class AppChrome extends ConsumerWidget {
  const AppChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider).value ?? false;
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (offline)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(bottom: false, child: _OfflineBanner()),
          ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GlassCard(
          tone: GlassTone.surfaceStrong,
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 15, color: g.textMuted),
              const SizedBox(width: 8),
              // Flexible so the strip reflows gracefully on narrow phones,
              // large text scales, and wide test fonts instead of
              // overflowing the canvas.
              Flexible(
                child: Text(
                  "You're offline — AI is paused. Your study tools will wait.",
                  style: TextStyle(color: g.textMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
