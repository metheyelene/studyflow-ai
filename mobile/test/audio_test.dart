import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';

import 'helpers.dart';

void main() {
  AudioEpisode readyEpisode(
    String id, {
    String status = 'ready',
    String stage = 'ready',
  }) {
    return AudioEpisode(
      id: id,
      title: 'VLSI Unit 3 — Study Podcast',
      style: 'focused',
      length: 'standard',
      status: status,
      pipelineStage: stage,
      audioUrl: '/api/audio/$id/stream',
      notebookId: 'nb-1',
      notebookTitle: 'VLSI Unit 3',
      durationSec: 300,
      wordCount: 900,
      createdAt: DateTime(2026, 8, 12),
      transcript: const [
        TranscriptSection(
          heading: 'Introduction',
          text: 'Welcome to your study session.',
          startSec: 0,
        ),
        TranscriptSection(
          heading: 'Core concepts',
          text:
              'Threshold voltage is the gate voltage at which a channel forms.',
          startSec: 30,
          sources: ['VLSI Notes'],
        ),
      ],
    );
  }

  group('Podcast library', () {
    testWidgets('shows an honest empty state', (tester) async {
      final audio = FakeAudioRepository();
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router);
      router.go('/audio');
      await tester.pumpAndSettle();

      expect(find.text('NO EPISODES'), findsOneWidget);
    });

    testWidgets('lists episodes with ready status', (tester) async {
      final audio = FakeAudioRepository(
        episodes: [readyEpisode('ep-1'), readyEpisode('ep-2')],
      );
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router);
      router.go('/audio');
      await tester.pumpAndSettle();

      expect(find.text('VLSI UNIT 3 — STUDY PODCAST'), findsNWidgets(2));
    });
  });

  group('Podcast player', () {
    testWidgets(
      'downloads and plays the episode, shows transcript and chapters',
      (tester) async {
        final audio = FakeAudioRepository(episodes: [readyEpisode('ep-1')]);
        final player = FakePodcastPlayer();
        final router = buildAppRouter();
        await pumpApp(
          tester,
          audio: audio,
          router: router,
          podcastPlayer: player,
        );
        router.go('/audio/ep-1');
        await tester.pumpAndSettle();

        expect(find.text('VLSI UNIT 3 — STUDY PODCAST'), findsWidgets);
        expect(player.loadedBytes, isNotNull);
        expect(player.playing, isTrue);
        expect(find.text('CHAPTERS'), findsOneWidget);
        expect(find.text('TRANSCRIPT'), findsOneWidget);
        expect(find.text('CORE CONCEPTS'), findsWidgets);
      },
    );

    testWidgets('resumes from the saved position', (tester) async {
      final audio = FakeAudioRepository(
        episodes: [readyEpisode('ep-1').copyWith(playbackPositionSec: 74)],
      );
      final player = FakePodcastPlayer();
      final router = buildAppRouter();
      await pumpApp(
        tester,
        audio: audio,
        router: router,
        podcastPlayer: player,
      );
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      expect(player.lastSeek, const Duration(seconds: 74));
    });

    testWidgets('failed episode shows the friendly error', (tester) async {
      final audio = FakeAudioRepository(
        episodes: [
          readyEpisode('ep-1', status: 'failed', stage: 'failed').copyWith(
            errorMessage:
                'This notebook has no indexed sources yet. Add a source first.',
          ),
        ],
      );
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router);
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      expect(find.textContaining('EPISODE FAILED'), findsOneWidget);
      expect(find.textContaining('no indexed sources'), findsOneWidget);
    });
  });
}
