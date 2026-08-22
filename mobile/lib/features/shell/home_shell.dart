import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../features/audio/audio_playback_service.dart';
import '../../features/audio/now_playing.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../../shared/widgets/swiss/swiss_mini_player.dart';

/// Kept for backward compatibility with tests.
int moodForTab(int index) => index;

const kHomeNavItems = [
  (Icons.home, 'Home'),
  (Icons.library_books, 'Notebooks'),
  (Icons.school, 'Study'),
  (Icons.headphones, 'Audio'),
  (Icons.insights, 'Progress'),
  (Icons.person, 'Profile'),
];

/// Swiss navigation shell — architectural bottom bar on phones, rail on desktop.
class HomeShell extends ConsumerWidget {
  const HomeShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = ref.watch(nowPlayingProvider);
    final isWide = MediaQuery.sizeOf(context).width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;
    final mutedBg = isDark ? SwissColors.darkMuted : SwissColors.muted;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(child: child),

          // Mini-player
          if (nowPlaying != null)
            Positioned(
              left: SwissSpacing.md,
              right: SwissSpacing.md,
              bottom: isWide ? SwissSpacing.md : 84,
              child: SwissMiniPlayer(
                title: nowPlaying.title,
                subtitle: nowPlaying.subtitle,
                playing: nowPlaying.playing,
                progress: nowPlaying.progress,
                completed: nowPlaying.completed,
                heroTag: 'podcast-artwork-${nowPlaying.episodeId}',
                onPlayPause: () {
                  final notifier = ref.read(nowPlayingProvider.notifier);
                  final player = ref.read(podcastPlayerProvider);
                  if (nowPlaying.playing) {
                    player.pause();
                    notifier.setPlaying(false);
                  } else {
                    player.play();
                    notifier.setPlaying(true);
                  }
                },
                onReplay: () => ref.read(nowPlayingProvider.notifier).replay(),
                onScrub: (fraction) =>
                    ref.read(nowPlayingProvider.notifier).seekToFraction(fraction),
                onOpen: () =>
                    context.push('${AppRoutes.audio}/${nowPlaying.episodeId}'),
              ),
            ),

          // Navigation
          if (isWide)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _SwissNavRail(
                items: kHomeNavItems,
                currentIndex: currentIndex,
                onTap: onDestinationSelected,
                extended: MediaQuery.sizeOf(context).width > 1024,
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SwissBottomNav(
                items: kHomeNavItems,
                currentIndex: currentIndex,
                onTap: onDestinationSelected,
              ),
            ),
        ],
      ),
    );
  }
}

/// Swiss bottom navigation — thick border top, no rounded corners.
class _SwissBottomNav extends StatelessWidget {
  const _SwissBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<(IconData, String)> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark ? SwissColors.darkBorder : SwissColors.black,
            width: SwissShapes.borderMedium,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwissSpacing.xs),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    child: _SwissNavItem(
                      icon: items[i].$1,
                      label: items[i].$2,
                      active: currentIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwissNavItem extends StatelessWidget {
  const _SwissNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.4)
        : SwissColors.black.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active indicator
          if (active)
            Container(
              width: 24,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              color: SwissColors.red,
            )
          else
            const SizedBox(height: 7),
          Icon(
            icon,
            size: 22,
            color: active ? fg : mutedFg,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: SwissTypography.caption.copyWith(
              fontSize: 9,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: active ? fg : mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swiss navigation rail — thick border right, no rounded corners.
class _SwissNavRail extends StatelessWidget {
  const _SwissNavRail({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.extended = false,
  });

  final List<(IconData, String)> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.4)
        : SwissColors.black.withValues(alpha: 0.4);

    return Container(
      width: extended ? 200 : 72,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(
            color: isDark ? SwissColors.darkBorder : SwissColors.black,
            width: SwissShapes.borderMedium,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: SwissSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  color: fg,
                  alignment: Alignment.center,
                  child: Icon(Icons.school, size: 18, color: bg),
                ),
                if (extended) ...[
                  const SizedBox(width: SwissSpacing.sm),
                  Text(
                    'STUDYFLOW',
                    style: SwissTypography.label.copyWith(
                      color: fg,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SwissDivider(),
          // Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SwissSpacing.sm),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SwissRailItem(
                      icon: items[i].$1,
                      label: items[i].$2,
                      active: currentIndex == i,
                      extended: extended,
                      onTap: () => onTap(i),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwissRailItem extends StatelessWidget {
  const _SwissRailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.extended = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.4)
        : SwissColors.black.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: extended ? SwissSpacing.md : SwissSpacing.sm,
          vertical: SwissSpacing.sm,
        ),
        color: active
            ? (isDark ? SwissColors.darkMuted : SwissColors.muted)
            : Colors.transparent,
        child: Row(
          children: [
            if (!extended) ...[
              // Active indicator
              if (active)
                Container(
                  width: 3,
                  height: 24,
                  margin: const EdgeInsets.only(right: 8),
                  color: SwissColors.red,
                )
              else
                const SizedBox(width: 11),
              Icon(
                icon,
                size: 22,
                color: active ? fg : mutedFg,
              ),
            ] else ...[
              Icon(
                icon,
                size: 20,
                color: active ? fg : mutedFg,
              ),
              const SizedBox(width: SwissSpacing.sm),
              Text(
                label.toUpperCase(),
                style: SwissTypography.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.0,
                  color: active ? fg : mutedFg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
