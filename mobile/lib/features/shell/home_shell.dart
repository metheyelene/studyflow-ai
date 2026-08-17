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
  GlassNavItem(label: 'Home', icon: Icons.home, selectedIcon: Icons.home),
  GlassNavItem(
    label: 'Notebooks',
    icon: Icons.library_books,
    selectedIcon: Icons.library_books,
  ),
  GlassNavItem(label: 'Study', icon: Icons.school, selectedIcon: Icons.school),
  GlassNavItem(
    label: 'Audio',
    icon: Icons.headphones,
    selectedIcon: Icons.headphones,
  ),
  GlassNavItem(
    label: 'Progress',
    icon: Icons.insights,
    selectedIcon: Icons.insights,
  ),
  GlassNavItem(
    label: 'Profile',
    icon: Icons.person,
    selectedIcon: Icons.person,
  ),
];

/// Each shell destination gets its own atmosphere, so the ambient
/// environment quietly matches what the user is doing: Home a calm glow,
/// Notebooks/Study the teal focus wash, Audio a warm coral field, Progress
/// cyan intelligence, and Profile a golden premium sheen.
BackgroundMood moodForTab(int index) => switch (index) {
  0 => BackgroundMood.ambient,
  1 || 2 => BackgroundMood.study,
  3 => BackgroundMood.audio,
  4 => BackgroundMood.ai,
  _ => BackgroundMood.premium,
};

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
    final mood = moodForTab(currentIndex);
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
            // Mini-player slot: always present so the switcher can animate
            // it out. Appears with a gentle rise+fade; dismissing (or the
            // auto-dismissed completed pill) slides down and fades out.
            // Phones keep the full-width strip above the nav bar; tablets
            // and desktop get a bottom-right floating card with an
            // artwork-driven ambient glow behind it.
            if (context.isPhone)
              Positioned(
                left: 12,
                right: 12,
                bottom: 84,
                child: _miniSwitcher(ref, nowPlaying, context),
              )
            else
              Positioned(
                right: 24,
                bottom: 24,
                child: _desktopMiniPlayer(ref, nowPlaying, context),
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

  /// The mini-player slot (or its empty state). Accepts null so the
  /// switcher can animate the pill out when playback ends.
  Widget _miniSwitcher(
    WidgetRef ref,
    NowPlaying? nowPlaying,
    BuildContext context,
  ) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: nowPlaying == null
          ? const SizedBox.shrink(key: ValueKey('mini-none'))
          : KeyedSubtree(
              key: ValueKey(
                'mini-${nowPlaying.episodeId}-'
                '${nowPlaying.completed}',
              ),
              child: _miniPlayer(ref, nowPlaying, context),
            ),
    );
  }

  /// Tablet/desktop: a compact bottom-right card with a soft ambient glow
  /// tinted by the artwork's coral accent behind it (decorative — dropped
  /// when reduced effects are on).
  Widget _desktopMiniPlayer(
    WidgetRef ref,
    NowPlaying? nowPlaying,
    BuildContext context,
  ) {
    final g = context.glass;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (nowPlaying != null && !g.reducedEffects)
          // The bloom is centered on the card (card ≈ 360×82; bloom 460)
          // and extends up-left into the content area, softly — the corner
          // itself stays clean.
          Positioned(
            right: -50,
            top: -190,
            child: IgnorePointer(
              child: Container(
                key: const Key('mini-player-glow'),
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      g.audio.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.16
                            : 0.10,
                      ),
                      g.audio.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: _miniSwitcher(ref, nowPlaying, context),
        ),
      ],
    );
  }

  Widget _miniPlayer(
    WidgetRef ref,
    NowPlaying nowPlaying,
    BuildContext context,
  ) {
    return GlassMiniPlayer(
      title: nowPlaying.title,
      subtitle: nowPlaying.subtitle,
      playing: nowPlaying.playing,
      progress: nowPlaying.progress,
      completed: nowPlaying.completed,
      heroTag: 'podcast-artwork-${nowPlaying.episodeId}',
      onPlayPause: () => _togglePlay(ref, nowPlaying),
      onReplay: () => ref.read(nowPlayingProvider.notifier).replay(),
      onScrub: (fraction) =>
          ref.read(nowPlayingProvider.notifier).seekToFraction(fraction),
      onOpen: () => context.push('${AppRoutes.audio}/${nowPlaying.episodeId}'),
    );
  }
}
