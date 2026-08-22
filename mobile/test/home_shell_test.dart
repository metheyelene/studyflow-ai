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
import 'package:studyflow_mobile/shared/widgets/swiss/swiss_mini_player.dart';

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

  group('moodForTab', () {
    test('every destination returns a valid index', () {
      // Swiss style: moodForTab returns the index itself
      expect(moodForTab(0), 0);
      expect(moodForTab(1), 1);
      expect(moodForTab(2), 2);
      expect(moodForTab(3), 3);
      expect(moodForTab(4), 4);
      expect(moodForTab(5), 5);
    });
  });

  group('HomeShell navigation', () {
    testWidgets('tab switches update the index', (tester) async {
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
      await tester.tap(find.byIcon(Icons.library_books));
      await tester.pumpAndSettle();
      expect(find.text('tab 1'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.headphones));
      await tester.pumpAndSettle();
      expect(find.text('tab 3'), findsOneWidget);
    });
  });

  group('Mini-player', () {
    testWidgets('floats over the shell with live play/pause', (tester) async {
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
      container
          .read(nowPlayingProvider.notifier)
          .setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pumpAndSettle();

      expect(find.text('VLSI UNIT 3 — STUDY PODCAST'), findsOneWidget);
      expect(find.text('VLSI Unit 3'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      expect(player.playing, isTrue);
    });

    testWidgets('collapses when the episode completes', (tester) async {
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
      container
          .read(nowPlayingProvider.notifier)
          .setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pump();

      player.emitCompleted();
      await tester.pumpAndSettle();
      // Collapsed pill: replay affordance, no play/pause.
      expect(find.byIcon(Icons.replay), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Replay restarts from zero and expands back to the full state.
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pumpAndSettle();
      expect(player.lastSeek, Duration.zero);
      expect(player.playing, isTrue);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('artwork carries the shared-element tag', (tester) async {
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
      container
          .read(nowPlayingProvider.notifier)
          .setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pump();

      expect(
        tester.widget<Hero>(find.byType(Hero)).tag,
        'podcast-artwork-ep-1',
      );
    });

    testWidgets('tapping the mini-player opens the full player', (tester) async {
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
      container
          .read(nowPlayingProvider.notifier)
          .setEpisode(
            episodeId: 'ep-1',
            title: 'VLSI Unit 3 — Study Podcast',
            subtitle: 'VLSI Unit 3',
          );
      await tester.pumpAndSettle();

      await tester.tap(find.text('VLSI UNIT 3 — STUDY PODCAST'));
      await tester.pumpAndSettle();

      expect(find.text('CHAPTERS'), findsOneWidget);
      expect(player.loadedBytes, isNotNull);
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
      expect(find.byType(SwissMiniPlayer), findsNothing);
    });
  });
}
