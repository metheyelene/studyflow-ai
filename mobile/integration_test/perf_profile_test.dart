import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/core/performance/memory_io.dart'
    if (dart.library.js_interop) 'package:studyflow_mobile/core/performance/memory_stub.dart'
    as memory;
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';

import '../test/helpers.dart';

/// Profile-build performance harness: drives the app's heaviest screens
/// (ambient background, glass nav, glass notebook workspace, a blurred
/// modal, the premium paywall, and the podcast player + transcript scroll)
/// while recording per-segment frame build/raster stats (traceAction) and
/// resident-set memory deltas.
///
/// Run:
///   flutter drive --profile -d macos \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_profile_test.dart
void main() {
  testWidgets('profile the heavy glass + animated screens', (tester) async {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    // Seeded fakes so every screen renders its real, content-rich state.
    final nbRepo = FakeNotebooksRepository()
      ..notebooks.add(
        Notebook(
          id: 'nb-1',
          title: 'Physics — Electromagnetics',
          description: 'Unit 3',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 12),
        ),
      )
      ..sources.addAll([
        NotebookSource(
          id: 'src-1',
          title: 'Lecture Notes — Maxwell',
          kind: 'pasted',
          status: SourceStatus.ready,
          wordCount: 4200,
          createdAt: DateTime(2026, 8, 2),
        ),
        NotebookSource(
          id: 'src-2',
          title: 'Textbook Ch. 5',
          kind: 'uploaded',
          status: SourceStatus.ready,
          pageCount: 24,
          createdAt: DateTime(2026, 8, 3),
        ),
        NotebookSource(
          id: 'src-3',
          title: 'Problem Set 2',
          kind: 'pasted',
          status: SourceStatus.processing,
          wordCount: 900,
          createdAt: DateTime(2026, 8, 4),
        ),
      ]);
    final audioRepo = FakeAudioRepository(
      episodes: [
        AudioEpisode(
          id: 'ep-1',
          title: 'VLSI Unit 3 — Study Podcast',
          style: 'focused',
          length: 'standard',
          status: 'ready',
          pipelineStage: 'ready',
          audioUrl: '/api/audio/ep-1/stream',
          notebookId: 'nb-1',
          notebookTitle: 'VLSI Unit 3',
          durationSec: 900,
          wordCount: 2400,
          createdAt: DateTime(2026, 8, 12),
          transcript: [
            for (var i = 0; i < 8; i++)
              TranscriptSection(
                heading: 'Section ${i + 1}',
                text:
                    'Threshold voltage is the gate voltage at which a channel '
                        'forms. This repeats to give the transcript a realistic '
                        'body length for scroll profiling.' *
                    4,
                startSec: i * 60,
                sources: ['VLSI Notes'],
              ),
          ],
        ),
      ],
    );
    final player = FakePodcastPlayer();
    final router = buildAppRouter();

    await pumpApp(
      tester,
      notebooks: nbRepo,
      audio: audioRepo,
      podcastPlayer: player,
      router: router,
    );

    // Real rasterization + continuous frames for the storms below.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    final results = <String, Object?>{};

    Future<void> storm(Duration duration) async {
      final end = DateTime.now().add(duration);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> segment(String label, Future<void> Function() action) async {
      final beforeRss = memory.currentRssKb();
      final timings = <FrameTiming>[];
      final scheduler = SchedulerBinding.instance;
      scheduler.addTimingsCallback(timings.addAll);
      try {
        await action();
      } finally {
        scheduler.removeTimingsCallback(timings.addAll);
      }
      final afterRss = memory.currentRssKb();

      if (timings.isEmpty) {
        results[label] = {
          'note': 'no frames captured',
          'rssDeltaKB': afterRss - beforeRss,
        };
        debugPrint('PERF | $label | ${results[label]}');
        return;
      }
      final builds = timings.map((t) => t.buildDuration.inMicroseconds / 1000);
      final rasters = timings.map(
        (t) => t.rasterDuration.inMicroseconds / 1000,
      );
      final sortedBuilds = builds.toList()..sort();
      final sortedRasters = rasters.toList()..sort();
      double percentile(List<double> sorted, int p) =>
          sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p / 100).round()];
      // 16 ms frame budget (mirrors FrameTiming.kBuildBudget in flutter_driver).
      const budget = Duration(microseconds: 16000);
      final missed = timings.where((t) => t.totalSpan > budget).length;
      results[label] = {
        'frames': timings.length,
        'rssDeltaKB': afterRss - beforeRss,
        'avgBuildMs': (builds.reduce((a, b) => a + b) / builds.length)
            .toStringAsFixed(2),
        'p90BuildMs': percentile(sortedBuilds, 90).toStringAsFixed(2),
        'worstBuildMs': sortedBuilds.last.toStringAsFixed(2),
        'avgRasterMs': (rasters.reduce((a, b) => a + b) / rasters.length)
            .toStringAsFixed(2),
        'worstRasterMs': sortedRasters.last.toStringAsFixed(2),
        'overBudgetFrames': missed,
      };
      debugPrint('PERF | $label | ${results[label]}');
    }

    // 1. Dashboard in the shell: ambient background + glossy hero + glass nav.
    await segment('1_dashboard', () => storm(const Duration(seconds: 3)));

    // 2. Tablet surface: the floating glass rail.
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);
    await tester.pump();
    await segment('2_tablet_rail', () => storm(const Duration(seconds: 2)));

    // 3. Notebook detail: glass workspace header + floating AI chips + glass sources.
    router.go('/notebooks/nb-1');
    await segment('3_notebook_detail', () async {
      await tester.pump(const Duration(milliseconds: 400));
      await storm(const Duration(seconds: 3));
    });

    // 4. Paste sheet: a BackdropFilter modal over the glass detail.
    await segment('4_paste_sheet', () async {
      await tester.tap(find.text('Paste text'));
      await tester.pump(const Duration(milliseconds: 400));
      await storm(const Duration(seconds: 2));
    });
    // Dismiss via the barrier.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 300));

    // 5. Premium: cards + founding offer.
    router.go('/premium');
    await segment('5_premium', () async {
      await tester.pump(const Duration(milliseconds: 400));
      await storm(const Duration(seconds: 3));
    });

    // 6. Podcast player: artwork gradient/glow + glass transcript cards.
    router.go('/audio/ep-1');
    await segment('6_podcast_player', () async {
      await tester.pump(const Duration(milliseconds: 600));
      await storm(const Duration(seconds: 3));
    });

    // 7. Scroll storm through the glass transcript list.
    await segment('7_podcast_scroll', () async {
      for (var i = 0; i < 12; i++) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -260),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 400));
    });

    debugPrint('PERF | FINAL | $results');
  });
}
