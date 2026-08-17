import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// Floating glass mini-player shown above navigation while an episode
/// plays after the user has left the full-screen player. Dumb surface:
/// state and controls are wired by the shell from `nowPlayingProvider`.
///
/// Two visual states:
///  * playing/paused — artwork, title, subtitle, play/pause and a thin
///    glass progress bar fed by real playback position;
///  * completed — auto-collapsed to a compact pill with a replay action.
class GlassMiniPlayer extends StatefulWidget {
  const GlassMiniPlayer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.progress,
    required this.completed,
    required this.onPlayPause,
    required this.onReplay,
    required this.onOpen,
    required this.onScrub,
    required this.heroTag,
  });

  /// Shared-element tag pairing the mini-player artwork with the full
  /// player screen's artwork, so tapping the card morphs into the player.
  final String heroTag;
  final String title;
  final String subtitle;
  final bool playing;

  /// 0..1 real playback progress.
  final double progress;

  /// True when the episode finished — renders the collapsed pill.
  final bool completed;
  final VoidCallback onPlayPause;
  final VoidCallback onReplay;
  final VoidCallback onOpen;

  /// Live playhead scrub: called with the finger's fraction while
  /// dragging (and on tap) so the caller can seek the player.
  final ValueChanged<double> onScrub;

  @override
  State<GlassMiniPlayer> createState() => _GlassMiniPlayerState();
}

class _GlassMiniPlayerState extends State<GlassMiniPlayer> {
  /// Finger-driven preview fraction while scrubbing; null when idle so the
  /// real playback progress drives the bar.
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final completed = widget.completed;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final playing = widget.playing;
    final progress = (_dragFraction ?? widget.progress).clamp(0.0, 1.0);
    final heroTag = widget.heroTag;
    final onPlayPause = widget.onPlayPause;
    final onReplay = widget.onReplay;
    final onOpen = widget.onOpen;
    if (completed) {
      return _CollapsedPill(
        heroTag: heroTag,
        title: title,
        onReplay: onReplay,
        onOpen: onOpen,
      );
    }
    return GlassCard(
      tone: GlassTone.surfaceStrong,
      blurred: g.blurEnabled,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
      // Tapping anywhere on the card opens the full player; the play/pause
      // button keeps its own tap inside.
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: _Artwork(
                    size: 42,
                    audio: g.audio,
                    background: g.background,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: g.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onPlayPause,
                  tooltip: playing ? 'Pause' : 'Play',
                  icon: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    size: 26,
                    color: g.primary,
                  ),
                ),
              ],
            ),
            // Draggable playhead on the real-position bar: scrubbing
            // previews under the finger and seeks the player live.
            _ScrubBar(
              progress: progress,
              onScrub: (fraction) {
                setState(() => _dragFraction = fraction);
                widget.onScrub(fraction);
              },
              onScrubEnd: () => setState(() => _dragFraction = null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draggable glass playhead. The visible track is thin but the hit area is
/// comfortably tall; a tap seeks, a horizontal drag scrubs live.
class _ScrubBar extends StatelessWidget {
  const _ScrubBar({
    required this.progress,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final double progress;
  final ValueChanged<double> onScrub;
  final VoidCallback onScrubEnd;

  double _fraction(double dx, double width) => (dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: const Key('mini-player-scrub'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onScrub(_fraction(d.localPosition.dx, width)),
            onHorizontalDragStart: (d) =>
                onScrub(_fraction(d.localPosition.dx, width)),
            onHorizontalDragUpdate: (d) =>
                onScrub(_fraction(d.localPosition.dx, width)),
            onHorizontalDragEnd: (_) => onScrubEnd(),
            child: SizedBox(
              height: 20,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: g.border),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            child: ColoredBox(color: g.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact pill shown when the episode has finished: artwork, title and a
/// replay action. Tapping anywhere reopens the full player.
class _CollapsedPill extends StatelessWidget {
  const _CollapsedPill({
    required this.heroTag,
    required this.title,
    required this.onReplay,
    required this.onOpen,
  });

  final String heroTag;
  final String title;
  final VoidCallback onReplay;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.surfaceStrong,
      blurred: g.blurEnabled,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: heroTag,
              child: _Artwork(
                size: 34,
                audio: g.audio,
                background: g.background,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onReplay,
              tooltip: 'Replay',
              icon: Icon(Icons.replay, size: 22, color: g.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.size,
    required this.audio,
    required this.background,
  });

  final double size;
  final Color audio;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [audio, Color.lerp(audio, background, 0.35)!],
        ),
      ),
      child: Icon(
        Icons.graphic_eq,
        size: size * 0.48,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}
