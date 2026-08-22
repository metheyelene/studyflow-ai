import 'package:flutter/material.dart';

import '../../../core/theme/swiss_tokens.dart';

/// Swiss mini player — flat rectangular bar above navigation.
class SwissMiniPlayer extends StatelessWidget {
  const SwissMiniPlayer({
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

  final String heroTag;
  final String title;
  final String subtitle;
  final bool playing;
  final double progress;
  final bool completed;
  final VoidCallback onPlayPause;
  final VoidCallback onReplay;
  final VoidCallback onOpen;
  final ValueChanged<double> onScrub;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkSurface : SwissColors.white;

    if (completed) {
      return _CollapsedPill(
        heroTag: heroTag,
        title: title,
        onReplay: onReplay,
        onOpen: onOpen,
        isDark: isDark,
        fg: fg,
        bg: bg,
      );
    }

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SwissSpacing.md,
          vertical: SwissSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isDark ? SwissColors.darkBorder : SwissColors.black,
            width: SwissShapes.borderThin,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Artwork
                Hero(
                  tag: heroTag,
                  child: Container(
                    width: 42,
                    height: 42,
                    color: fg,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.graphic_eq,
                      size: 20,
                      color: bg,
                    ),
                  ),
                ),
                const SizedBox(width: SwissSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwissTypography.subheading.copyWith(
                          color: fg,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwissTypography.caption.copyWith(
                          color: isDark
                              ? SwissColors.darkForeground.withValues(alpha: 0.5)
                              : SwissColors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 40,
                    height: 40,
                    color: SwissColors.red,
                    alignment: Alignment.center,
                    child: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      size: 22,
                      color: SwissColors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Progress bar
            const SizedBox(height: SwissSpacing.xs),
            GestureDetector(
              onHorizontalDragUpdate: (d) {
                // Simple scrub
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final fraction = (d.localPosition.dx / box.size.width)
                      .clamp(0.0, 1.0);
                  onScrub(fraction);
                }
              },
              child: Container(
                width: double.infinity,
                height: 3,
                color: isDark ? SwissColors.darkMuted : SwissColors.muted,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedPill extends StatelessWidget {
  const _CollapsedPill({
    required this.heroTag,
    required this.title,
    required this.onReplay,
    required this.onOpen,
    required this.isDark,
    required this.fg,
    required this.bg,
  });

  final String heroTag;
  final String title;
  final VoidCallback onReplay;
  final VoidCallback onOpen;
  final bool isDark;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SwissSpacing.md,
          vertical: SwissSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isDark ? SwissColors.darkBorder : SwissColors.black,
            width: SwissShapes.borderThin,
          ),
        ),
        child: Row(
          children: [
            Hero(
              tag: heroTag,
              child: Container(
                width: 34,
                height: 34,
                color: fg,
                alignment: Alignment.center,
                child: Icon(Icons.graphic_eq, size: 16, color: bg),
              ),
            ),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwissTypography.caption.copyWith(color: fg),
              ),
            ),
            GestureDetector(
              onTap: onReplay,
              child: Icon(Icons.replay, size: 20, color: SwissColors.red),
            ),
          ],
        ),
      ),
    );
  }
}
