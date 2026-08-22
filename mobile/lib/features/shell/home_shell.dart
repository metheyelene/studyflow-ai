import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/bauhaus_tokens.dart';
import '../../features/audio/audio_playback_service.dart';
import '../../features/audio/now_playing.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import '../../shared/widgets/glass/glass_mini_player.dart';

import '../../shared/widgets/glass/glass_background.dart';

/// Tab mood mapping — kept for backward compatibility with tests.
BackgroundMood moodForTab(int index) => switch (index) {
  0 => BackgroundMood.ambient,
  1 || 2 => BackgroundMood.study,
  3 => BackgroundMood.audio,
  4 => BackgroundMood.ai,
  _ => BackgroundMood.premium,
};

const kHomeNavItems = [
  BauhausNavItem(label: 'Home', icon: Icons.home, selectedIcon: Icons.home),
  BauhausNavItem(
    label: 'Notebooks',
    icon: Icons.library_books,
    selectedIcon: Icons.library_books,
  ),
  BauhausNavItem(label: 'Study', icon: Icons.school, selectedIcon: Icons.school),
  BauhausNavItem(
    label: 'Audio',
    icon: Icons.headphones,
    selectedIcon: Icons.headphones,
  ),
  BauhausNavItem(
    label: 'Progress',
    icon: Icons.insights,
    selectedIcon: Icons.insights,
  ),
  BauhausNavItem(
    label: 'Profile',
    icon: Icons.person,
    selectedIcon: Icons.person,
  ),
];

/// Adaptive navigation shell: bottom bar on phones, rail on tablet/desktop.
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

    return Scaffold(
      backgroundColor: BauhausColors.background,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: child,
          ),

          // Mini-player
          if (nowPlaying != null)
            Positioned(
              left: BauhausSpacing.md,
              right: BauhausSpacing.md,
              bottom: isWide ? BauhausSpacing.md : 84,
              child: GlassMiniPlayer(
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
              child: BauhausNavRail(
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
              child: BauhausBottomNav(
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
