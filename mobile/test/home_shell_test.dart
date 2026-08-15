import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';
import 'package:studyflow_mobile/features/audio/audio_playback_service.dart';
import 'package:studyflow_mobile/features/audio/now_playing.dart';
import 'package:studyflow_mobile/features/shell/home_shell.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_background.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_mini_player.dart';

import 'helpers.dart';

AudioEpisode readyEpisode(String id) => AudioEpisode(
      id: id,
      title: 'VLSI Unit 3 — Study Podcast',
      style: 'focused',
      length: 'standard',
      status: 'ready',
      pipelineStage: 'ready',
      audioUrl: '/api/audio/$id/stream',
      notebookId: 'nb-1',
      notebookTitle: 'VLSI Unit 3',
      durationSec: 300,
      wordCount: 900,
      createdAt: DateTime(2026, 8, 12),
      transcript: const [
        TranscriptSection(
          heading: 'Core concepts',
          text: 'Threshold voltage is the gate voltage at which a channel forms.',
          startSec: 30,
          sources: ['VLSI Notes'],
        ),
      ],
    );

void main() {
  Widget shell({
    required int index,
    required ValueChanged<int> onDestinationSelected,
    required Widget child,
    List<Override> extra = const [],
  }) {
    return ProviderScope(
      overrides: [
        performanceTierProvider.overrideWithValue(PerformanceTier.standard),
        ...extra,
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        home: HomeShell(
          currentIndex: index,
          onDestinationSelected: onDestinationSelected,
          child: child,
        ),
      ),
    );
  }

  group('StudyFlowBackground atmosphere', () {
    testWidgets('mood changes cross-fade, then settle', (tester) async {
      Widget bg(BackgroundMood mood) => ProviderScope(
            overrides: [
              performanceTierProvider.overrideWithValue(
                PerformanceTier.standard,
              ),
            ],
            child: MaterialApp(
              theme: buildAppTheme(Brightness.dark),
              home: StudyFlowBackground(mood: mood, child: const SizedBox()),
            ),
          );

      await tester.pumpWidget(bg(BackgroundMood.ambient));
      await tester.pumpAndSettle();
      expect(find.byKey(kStudyFlowBackgroundBlobs), findsOneWidget);

      // Switch mood: mid-transition the old and new atmosphere composite
      // together (the slow cross-fade), then it settles back to one.
      await tester.pumpWidget(bg(BackgroundMood.study));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(kStudyFlowBackgroundBlobs), findsNWidgets(2));

      await tester.pumpAndSettle();
      expect(find.byKey(kStudyFlowBackgroundBlobs), findsOneWidget);
    });
  });

  group('per-tab atmospheres', () {
    test('every destination has its own dedicated mood', () {
      expect(moodForTab(0), BackgroundMood.ambient); // Home: calm glow
      expect(moodForTab(1), BackgroundMood.study); // Notebooks
      expect(moodForTab(2), BackgroundMood.study); // Study
      expect(moodForTab(3), BackgroundMood.audio); // Audio: warm coral
      expect(moodForTab(4), BackgroundMood.ai); // Progress: cyan
      expect(moodForTab(5), BackgroundMood.premium); // Profile: golden
    });
  });

  group('HomeShell navigation', () {
    testWidgets('tab switches slide+fade instead of snapping', (
      tester,
    ) async {
      var index = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => shell(
            index: index,
            onDestinationSelected: (i) => setState(() => index = i),
            child: Text('tab $index'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('tab 0'), findsOneWidget);

      // 800×600 default surface → tablet rail, which shows icons only.
      await tester.tap(find.byIcon(Icons.library_books_outlined));
      // Mid-transition: the new branch fades in with a gentle rise — it is
      // present but still rising (never two branches at once: GoRouter's
      // navigators carry GlobalKeys).
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('tab 0'), findsNothing);
      expect(find.text('tab 1'), findsOneWidget);
      final rising = tester.widget<Transform>(
        find.byKey(const Key('shell-branch-rise')),
      );
      expect(rising.transform.getTranslation().y, greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.text('tab 1'), findsOneWidget);
      final settled = tester.widget<Transform>(
        find.byKey(const Key('shell-branch-rise')),
      );
      expect(settled.transform.getTranslation().y, 0);
    });

    testWidgets('Audio is a first-class tab destination', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => shell(
            index: index,
            onDestinationSelected: (i) => setState(() => index = i),
            child: Text('tab $index'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(kHomeNavItems.length, 6);

      await tester.tap(find.byIcon(Icons.headphones_outlined));
      await tester.pumpAndSettle();
      expect(find.text('tab 3'), findsOneWidget);
    });
  });

  group('Mini-player', () {
    testWidgets('floats over the shell with live play/pause', (tester) async {
      final player = FakePodcastPlayer();
      // Seed the notifier the way the full-screen player does.
      await tester.pumpWidget(
        shell(
          index: 0,
          onDestinationSelected: (_) {},
          child: const Text('home'),
          extra: [podcastPlayerProvider.overrideWithValue(player)],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(nowPlayingProvider.notifier).setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pumpAndSettle();

      expect(find.text('VLSI Unit 3 — Study Podcast'), findsOneWidget);
      expect(find.text('VLSI Unit 3'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Pause from the mini-player drives the singleton player and the
      // notifier together.
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(player.playing, isTrue);
    });

    testWidgets('progress bar tracks real playback position', (tester) async {
      final player = FakePodcastPlayer();
      await tester.pumpWidget(
        shell(
          index: 0,
          onDestinationSelected: (_) {},
          child: const Text('home'),
          extra: [podcastPlayerProvider.overrideWithValue(player)],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(nowPlayingProvider.notifier).setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pump();

      // Real position, not a clock: emit duration + position from the
      // player's own streams and the bar must reflect the fraction.
      player.emitDuration(const Duration(seconds: 300));
      player.emitPosition(const Duration(seconds: 150));
      await tester.pump();
      expect(
        tester
            .widget<GlassMiniPlayer>(find.byType(GlassMiniPlayer))
            .progress,
        closeTo(0.5, 0.001),
      );

      player.emitPosition(const Duration(seconds: 225));
      await tester.pump();
      expect(
        tester
            .widget<GlassMiniPlayer>(find.byType(GlassMiniPlayer))
            .progress,
        closeTo(0.75, 0.001),
      );
    });

    testWidgets('collapses when the episode completes, replays from zero', (
      tester,
    ) async {
      final player = FakePodcastPlayer();
      await tester.pumpWidget(
        shell(
          index: 0,
          onDestinationSelected: (_) {},
          child: const Text('home'),
          extra: [podcastPlayerProvider.overrideWithValue(player)],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(nowPlayingProvider.notifier).setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pump();

      player.emitCompleted();
      await tester.pumpAndSettle();
      // Collapsed pill: replay affordance, no play/pause, no progress bar.
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(
        tester
            .widget<GlassMiniPlayer>(find.byType(GlassMiniPlayer))
            .completed,
        isTrue,
      );

      // Replay restarts from zero and expands back to the full state.
      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();
      expect(player.lastSeek, Duration.zero);
      expect(player.playing, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(
        tester
            .widget<GlassMiniPlayer>(find.byType(GlassMiniPlayer))
            .completed,
        isFalse,
      );
    });

    testWidgets('artwork carries the shared-element tag in both states', (
      tester,
    ) async {
      final player = FakePodcastPlayer();
      await tester.pumpWidget(
        shell(
          index: 0,
          onDestinationSelected: (_) {},
          child: const Text('home'),
          extra: [podcastPlayerProvider.overrideWithValue(player)],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(nowPlayingProvider.notifier).setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pump();

      // Full state: the artwork is the hero source.
      expect(
        tester
            .widget<Hero>(find.byType(Hero))
            .tag,
        'podcast-artwork-ep-1',
      );

      // Completed state: the collapsed pill's artwork keeps the same tag.
      player.emitCompleted();
      await tester.pump();
      expect(
        tester
            .widget<Hero>(find.byType(Hero))
            .tag,
        'podcast-artwork-ep-1',
      );
    });

    testWidgets('tapping the mini-player morphs into the full player', (
      tester,
    ) async {
      final audio = FakeAudioRepository(episodes: [readyEpisode('ep-1')]);
      final player = FakePodcastPlayer();
      final router = buildAppRouter();
      await pumpApp(
        tester,
        audio: audio,
        router: router,
        podcastPlayer: player,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('Ready to study?')),
      );
      container.read(nowPlayingProvider.notifier).setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pumpAndSettle();

      // Tap the mini-player card → the full player opens via the
      // shared-element route (its artwork carries the same hero tag).
      await tester.tap(find.text('VLSI Unit 3 — Study Podcast'));
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsOneWidget);
      expect(player.loadedBytes, isNotNull);
      final heroes = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((h) => h.tag)
          .toList();
      expect(heroes, contains('podcast-artwork-ep-1'));
    });

    testWidgets('hidden when nothing is playing', (tester) async {
      await tester.pumpWidget(
        shell(
          index: 0,
          onDestinationSelected: (_) {},
          child: const Text('home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassMiniPlayer), findsNothing);
    });
  });
}
