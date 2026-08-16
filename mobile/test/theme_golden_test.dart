@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';
import 'package:studyflow_mobile/features/flashcards/flashcard_models.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_models.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';
import 'package:studyflow_mobile/features/quizzes/quiz_models.dart';

import 'helpers.dart';

/// Golden-image baselines for the app's major screens in both modes,
/// rendered at a fixed phone surface with the real router and fake
/// repositories (see [pumpApp]). These catch visual regressions the token
/// snapshot can't — layout drift, glass rendering, ambient composition,
/// spacing, and shadows.
///
/// The baselines are CI-AUTHORITATIVE: the pinned Linux container is the
/// only environment they are generated on. macOS's Skia build renders the
/// same scene ~2-5% of pixels differently (font/gradient rasterization
/// paths differ per OS even for embedded fonts), so local runs skip these
/// tests — they would only ever report that platform noise. CI
/// (`.github/workflows/ci.yml`) is their real judge: on every push it
/// regenerates them on the pinned Linux platform and fails if the result
/// drifts from what is committed.
///
/// Regenerate when a visual change is intentional by pushing and taking
/// the CI golden gate's `regenerated-goldens` artifact (or any Linux host
/// with Flutter 3.44.9):
///   flutter test --tags golden --update-goldens
///
/// Determinism on the Linux container comes from three pins:
///  * the exact Flutter SDK version in CI (engine rasterizer is version-
///    sensitive),
///  * `debugDefaultTargetPlatformOverride = TargetPlatform.android` so the
///    Material theme requests Roboto rather than a host-specific family,
///  * the bundled Roboto TTFs below (embedded fonts render with the
///    engine's own FreeType/Skia rasterizer, independent of the host OS).
/// Load the real Roboto weights (the Material default family the app uses —
/// no custom font in pubspec) so goldens render true glyphs and metrics
/// instead of flutter_test's blocky placeholder font. [FontLoader] has no
/// weight API; the engine reads the OS/2 weight from each TTF, so the three
/// static faces cover the theme's 400/500/700 weights and the engine picks
/// the nearest face for w600.
Future<void> _loadAppFonts() async {
  final dir = Directory('test/goldens/fonts');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('${dir.path}/$name').readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await _loadAppFonts();
    // Settings reads/writes the appearance preference; pin an empty store
    // so the golden renders the deterministic defaults.
    SharedPreferences.setMockInitialValues({});
  });

  const size = Size(390, 844);

  final now = DateTime(2026, 8, 12);

  // Deterministic seeds per screen so each golden shows real content. Home
  // keeps the empty-dashboard defaults so its baselines stay stable.
  ({
    FakeNotebooksRepository notebooks,
    FakeFlashcardsRepository flashcards,
    FakeQuizzesRepository quizzes,
    FakeAudioRepository audio,
  })
  seeds(String screen) {
    final notebooks = FakeNotebooksRepository();
    var flashcards = FakeFlashcardsRepository();
    var quizzes = FakeQuizzesRepository();
    var audio = FakeAudioRepository();

    if (screen == 'progress_history') {
      // Review history that matches progress_test's sample: weighted
      // mastery = (75*4 + 0*2) / 6 = 50%, with Thermo the weakest deck.
      flashcards = FakeFlashcardsRepository()
        ..progressData = const FlashcardProgress(
          totalReviews: 6,
          uniqueCards: 3,
          decks: [
            DeckAccuracy(
              deckId: 'deck_a',
              title: 'VLSI Unit 3',
              reviews: 4,
              remembered: 3,
              accuracy: 75,
            ),
            DeckAccuracy(
              deckId: 'deck_b',
              title: 'Thermo',
              reviews: 2,
              remembered: 0,
              accuracy: 0,
            ),
          ],
        );
    }
    if (screen == 'study_space') {
      notebooks.notebooks.add(
        Notebook(
          id: 'nb-1',
          title: 'VLSI — Unit 3',
          description: 'Electromagnetics and device physics',
          createdAt: now,
          updatedAt: now,
          sourceCount: 1,
        ),
      );
      notebooks.sources.add(
        NotebookSource(
          id: 'src-1',
          title: 'Lecture 4 — Electromagnetics',
          kind: 'uploaded',
          status: SourceStatus.ready,
          wordCount: 1240,
          pageCount: 18,
          createdAt: now,
        ),
      );
    }
    if (screen == 'flashcards') {
      flashcards = FakeFlashcardsRepository(
        decks: [
          FlashcardDeck(
            id: 'deck-1',
            title: 'VLSI Unit 3 — Key Concepts',
            cardCount: 2,
            notebookId: 'nb-1',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        cards: const [
          Flashcard(
            id: 'card-1',
            front: 'What is the switching threshold of a CMOS inverter?',
            back: 'The input voltage where the output sits between rails.',
          ),
          Flashcard(
            id: 'card-2',
            front: 'Why is the noise margin important?',
            back: 'It quantifies immunity to signal degradation.',
          ),
        ],
      );
    }
    if (screen == 'quiz') {
      quizzes = FakeQuizzesRepository(
        quizzes: [
          QuizSummary(
            id: 'quiz-1',
            title: 'Electromagnetics Checkpoint',
            questionCount: 2,
            difficulty: 'medium',
            notebookId: 'nb-1',
            createdAt: now,
          ),
        ],
        questions: const [
          QuizQuestion(
            id: 'q-1',
            question: 'Which quantity is conserved in a closed circuit?',
            options: ['Charge', 'Voltage', 'Resistance', 'Power'],
            correctIndex: 0,
            explanation: 'Charge is conserved; energy is converted.',
          ),
          QuizQuestion(
            id: 'q-2',
            question: 'The electric field inside a perfect conductor is:',
            options: ['Zero', 'Maximum', 'Constant', 'Infinite'],
            correctIndex: 0,
            explanation: 'Free charges redistribute to cancel the field.',
          ),
        ],
      );
    }
    if (screen == 'podcast_library' || screen == 'audio_player') {
      // Ready episodes only — a processing episode's spinner animates
      // forever and would break pumpAndSettle. The library lists both;
      // the player screen downloads the first one, plays it through the
      // fake player (no position events, so the frame is stable), and
      // shows artwork + progress + chapters.
      final ready = [
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
          durationSec: 300,
          wordCount: 900,
          createdAt: now,
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
        ),
        AudioEpisode(
          id: 'ep-2',
          title: 'Signals — Convolution Basics',
          style: 'friendly',
          length: 'quick',
          status: 'ready',
          pipelineStage: 'ready',
          audioUrl: '/api/audio/ep-2/stream',
          notebookId: 'nb-2',
          notebookTitle: 'Signals & Systems',
          durationSec: 180,
          wordCount: 540,
          createdAt: now,
        ),
      ];
      audio = FakeAudioRepository(
        episodes: screen == 'podcast_library' ? ready : [ready[0]],
      );
    }
    // premium and profile need no special seeding: pumpApp's default
    // FakePlayBillingRepository shows the active founding offer ($2,
    // 23 of 35 remaining) on a free plan — the real Premium presentation.
    return (
      notebooks: notebooks,
      flashcards: flashcards,
      quizzes: quizzes,
      audio: audio,
    );
  }

  // `path` null means the screen is reached through pumpApp's own router
  // state (login needs signedIn false; onboarding needs the needed gate)
  // rather than a post-pump navigation.
  final screens = const [
    (
      name: 'home',
      path: AppRoutes.home,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'study_space',
      path: '/notebooks/nb-1',
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'flashcards',
      path: '/flashcards/deck-1',
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'quiz',
      path: '/quizzes/quiz-1',
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'podcast_library',
      path: AppRoutes.audio,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'audio_player',
      path: '/audio/ep-1',
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'premium',
      path: AppRoutes.premium,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'profile',
      path: AppRoutes.profile,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'progress_empty',
      path: AppRoutes.progress,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'progress_history',
      path: AppRoutes.progress,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'settings',
      path: AppRoutes.settings,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (
      name: 'about_creator',
      path: AppRoutes.aboutCreator,
      signedIn: true,
      onboardingNeeded: false,
    ),
    (name: 'login', path: null, signedIn: false, onboardingNeeded: false),
    (name: 'onboarding', path: null, signedIn: true, onboardingNeeded: true),
  ];

  // Baselines are generated on the pinned Linux CI container; other hosts
  // render 2-5% of pixels differently and can never match them, so skip
  // (reported as skipped, not failed) outside Linux. CI still enforces the
  // goldens exactly via its regenerate+diff gate.
  final goldensEnabled = Platform.isLinux;

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    for (final screen in screens) {
      testWidgets('${screen.name} golden — $mode', (tester) async {
        // Material's default family is platform-dependent: pin Android so
        // the theme requests Roboto (the app's real font) rather than SF
        // Pro on the macOS host. Reset inside the test body — the binding's
        // invariant check runs before addTearDown callbacks.
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        // ThemeMode.system → the app follows platform brightness.
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        final router = buildAppRouter();
        final seed = seeds(screen.name);
        await pumpApp(
          tester,
          router: router,
          size: size,
          tier: PerformanceTier.standard,
          signedIn: screen.signedIn,
          onboardingStatus: screen.onboardingNeeded
              ? OnboardingStatus.needed
              : null,
          notebooks: seed.notebooks,
          flashcards: seed.flashcards,
          quizzes: seed.quizzes,
          audio: seed.audio,
        );
        final path = screen.path;
        if (path != null && path != AppRoutes.home) {
          router.go(path);
          // Let the route's finite entrance motion settle.
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${screen.name}_$mode.png'),
        );
        debugDefaultTargetPlatformOverride = null;
      }, skip: !goldensEnabled);
    }
  }
}
