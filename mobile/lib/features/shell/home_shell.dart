import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../features/audio/audio_playback_service.dart';
import '../../features/audio/now_playing.dart';
import '../../shared/widgets/glass/glass_background.dart';
import '../../shared/widgets/glass/glass_mini_player.dart';
import '../../shared/widgets/glass/glass_nav.dart';

const kHomeNavItems = [
  GlassNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  GlassNavItem(
    label: 'Notebooks',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
  ),
  GlassNavItem(
    label: 'Study',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  GlassNavItem(
    label: 'Progress',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
  ),
  GlassNavItem(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

/// Adaptive navigation shell: floating bottom bar on phones, floating
/// rail on tablet/desktop. The branch body is provided by the router
/// (StatefulShellRoute.indexedStack).
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
    // The ambient background responds to the active tab: Home gets the
    // default calm glow, Notebooks/Study the study mood, Audio the deep
    // media wash, Premium-ish Profile a warmer sheen.
    final mood = switch (currentIndex) {
      0 => BackgroundMood.ambient,
      1 || 2 => BackgroundMood.study,
      3 => BackgroundMood.ai,
      _ => BackgroundMood.ambient,
    };
    final nowPlaying = ref.watch(nowPlayingProvider);
    return Scaffold(
      body: StudyFlowBackground(
        mood: mood,
        child: Stack(
          children: [
            // Liquid branch switch: each new tab's content fades in with a
            // gentle rise instead of snapping. The old branch is replaced in
            // the same frame (GoRouter's branch navigators carry GlobalKeys,
            // so two may never coexist), and the fade is finite so tests
            // settle.
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(currentIndex),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: AppMotion.medium,
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    key: const Key('shell-branch-rise'),
                    offset: Offset(0, 10 * (1 - t)),
                    child: child,
                  ),
                ),
                child: child,
              ),
            ),
            if (nowPlaying != null)
              if (context.isPhone)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 84,
                  child: _miniPlayer(ref, nowPlaying, context),
                )
              else
                Positioned(
                  left: 96,
                  right: 16,
                  bottom: 16,
                  child: _miniPlayer(ref, nowPlaying, context),
                ),
            if (context.isPhone)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassNavigationBar(
                  items: kHomeNavItems,
                  currentIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                ),
              )
            else
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GlassNavigationRail(
                    items: kHomeNavItems,
                    currentIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                    extended: context.isDesktop,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Drive the singleton player and mirror the state to the notifier so
  /// the mini-player and the full-screen player agree.
  void _togglePlay(WidgetRef ref, NowPlaying nowPlaying) {
    final notifier = ref.read(nowPlayingProvider.notifier);
    final player = ref.read(podcastPlayerProvider);
    if (nowPlaying.playing) {
      player.pause();
      notifier.setPlaying(false);
    } else {
      player.play();
      notifier.setPlaying(true);
    }
  }

  Widget _miniPlayer(WidgetRef ref, NowPlaying nowPlaying, BuildContext context) {
    return GlassMiniPlayer(
      title: nowPlaying.title,
      subtitle: nowPlaying.subtitle,
      playing: nowPlaying.playing,
      progress: nowPlaying.progress,
      completed: nowPlaying.completed,
      onPlayPause: () => _togglePlay(ref, nowPlaying),
      onReplay: () => ref.read(nowPlayingProvider.notifier).replay(),
      onOpen: () => context.push(
        '${AppRoutes.audio}/${nowPlaying.episodeId}',
      ),
    );
  }
}
