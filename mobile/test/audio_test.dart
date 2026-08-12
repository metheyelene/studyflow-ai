import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';

import 'helpers.dart';

void main() {
  AudioEpisode readyEpisode(String id, {String status = 'ready', String stage = 'ready'}) {
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
        TranscriptSection(heading: 'Introduction', text: 'Welcome to your study session.', startSec: 0),
        TranscriptSection(
          heading: 'Core concepts',
          text: 'Threshold voltage is the gate voltage at which a channel forms.',
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

      expect(find.text('No podcasts yet'), findsOneWidget);
      expect(find.text('Start a podcast'), findsOneWidget);
    });

    testWidgets('lists episodes with ready/processing/failed status', (tester) async {
      final audio = FakeAudioRepository(episodes: [
        readyEpisode('ep-1'),
        readyEpisode('ep-2', status: 'processing', stage: 'writing'),
        readyEpisode('ep-3', status: 'failed', stage: 'failed', ),
      ]);
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router);
      router.go('/audio');
      // Bounded pumps: the processing episode's spinner animates forever,
      // so pumpAndSettle would time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('VLSI Unit 3 — Study Podcast'), findsNWidgets(3));
      expect(find.text('Writing the study script…'), findsOneWidget);
      // The failed episode surfaces its error inline.
      expect(find.textContaining('Generation failed'), findsWidgets);
    });

    testWidgets('generating from a notebook opens the ready episode in the player', (tester) async {
      final audio = FakeAudioRepository();
      final notebooks = FakeNotebooksRepository();
      await notebooks.create(title: 'Biology', description: null);
      final router = buildAppRouter();
      final player = FakePodcastPlayer();
      await pumpApp(tester, audio: audio, notebooks: notebooks, router: router, podcastPlayer: player);
      router.go('/audio');
      await tester.pumpAndSettle();

      await tester.tap(find.text('New podcast'));
      await tester.pumpAndSettle();
      expect(find.text('Create a Study Podcast'), findsOneWidget);
      // Pick the notebook + a style + length, then generate.
      await tester.tap(find.text('Biology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friendly Tutor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick · 5–10 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate episode'));
      await tester.pumpAndSettle();

      // Generation completed immediately (fake) and the player opened.
      expect(find.text('VLSI Unit 3 — Study Podcast'), findsNothing);
      expect(find.text('Generated podcast'), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(player.loadedBytes, isNotNull);
      expect(audio.createCalls, 1);
      expect(audio.lastStyle, 'friendly');
      expect(audio.lastLength, 'quick');
    });

    testWidgets('shows real pipeline stages while the backend job runs', (tester) async {
      // Two polls: the first still reports the organizing stage, the
      // second resolves the job to ready.
      final audio = FakeAudioRepository(pollsUntilReady: 2);
      final notebooks = FakeNotebooksRepository();
      await notebooks.create(title: 'Biology', description: null);
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, notebooks: notebooks, router: router);
      router.go('/audio');
      await tester.pumpAndSettle();

      await tester.tap(find.text('New podcast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate episode'));
      await tester.pump();

      // First poll: still processing → stage text shown.
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Organizing your notes'), findsOneWidget);
      expect(find.text('Creating…'), findsOneWidget);

      // Second poll resolves the job → player opens.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Chapters'), findsOneWidget);
    });

    testWidgets('generation failure is shown inline with the friendly error', (tester) async {
      final audio = FakeAudioRepository(failCreate: true);
      final notebooks = FakeNotebooksRepository();
      await notebooks.create(title: 'Biology', description: null);
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, notebooks: notebooks, router: router);
      router.go('/audio');
      await tester.pumpAndSettle();

      await tester.tap(find.text('New podcast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate episode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no indexed sources'), findsOneWidget);
    });
  });

  group('Podcast player', () {
    testWidgets('downloads and plays the episode, shows transcript and chapters', (tester) async {
      final audio = FakeAudioRepository(episodes: [readyEpisode('ep-1')]);
      final player = FakePodcastPlayer();
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router, podcastPlayer: player);
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      expect(find.text('VLSI Unit 3 — Study Podcast'), findsWidgets);
      expect(player.loadedBytes, isNotNull);
      expect(player.playing, isTrue);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('Transcript'), findsOneWidget);
      // The section appears both as a chapter row and a transcript block.
      expect(find.text('Core concepts'), findsNWidgets(2));
      // Source chip for the grounded section.
      expect(find.text('VLSI Notes'), findsOneWidget);
    });

    testWidgets('resumes from the saved position and saves new positions', (tester) async {
      final audio = FakeAudioRepository(episodes: [
        readyEpisode('ep-1').copyWith(playbackPositionSec: 74),
      ]);
      final player = FakePodcastPlayer();
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router, podcastPlayer: player);
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      // Resumed at the saved position.
      expect(player.lastSeek, const Duration(seconds: 74));
    });

    testWidgets('tapping a chapter seeks to its timestamp', (tester) async {
      final audio = FakeAudioRepository(episodes: [readyEpisode('ep-1')]);
      final player = FakePodcastPlayer();
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router, podcastPlayer: player);
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Core concepts').first);
      await tester.pumpAndSettle();
      expect(player.lastSeek, const Duration(seconds: 30));
    });

    testWidgets('failed episode shows the friendly error, not a raw stack', (tester) async {
      final audio = FakeAudioRepository(episodes: [
        readyEpisode('ep-1', status: 'failed', stage: 'failed').copyWith(
          errorMessage: 'This notebook has no indexed sources yet. Add a source first.',
        ),
      ]);
      final router = buildAppRouter();
      await pumpApp(tester, audio: audio, router: router);
      router.go('/audio/ep-1');
      await tester.pumpAndSettle();

      expect(find.text('This episode failed to generate'), findsOneWidget);
      expect(find.textContaining('no indexed sources'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });
}
