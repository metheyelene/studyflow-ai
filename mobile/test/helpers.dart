import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/core/theme/theme_controller.dart';
import 'package:studyflow_mobile/features/audio/audio_models.dart';
import 'package:studyflow_mobile/features/audio/audio_playback_service.dart';
import 'package:studyflow_mobile/features/audio/audio_repository.dart';
import 'package:studyflow_mobile/features/authentication/auth_controller.dart';
import 'package:studyflow_mobile/features/authentication/auth_models.dart';
import 'package:studyflow_mobile/features/authentication/auth_repository.dart';
import 'package:studyflow_mobile/features/dashboard/dashboard_repository.dart';
import 'package:studyflow_mobile/features/flashcards/flashcard_models.dart';
import 'package:studyflow_mobile/features/flashcards/flashcards_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
import 'package:studyflow_mobile/features/quizzes/quiz_models.dart';
import 'package:studyflow_mobile/features/quizzes/quizzes_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_controller.dart';
import 'package:studyflow_mobile/features/study/study_planner.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_models.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_repository.dart';
import 'package:studyflow_mobile/features/premium/play_billing_repository.dart';
import 'package:studyflow_mobile/features/premium/premium_models.dart';

const testUser = AuthUser(
  id: 'user_1',
  name: 'Test User',
  email: 'test@example.com',
);

/// In-memory auth repository. [current] starts signed in so most tests
/// boot straight into the app; set it to null for auth-screen tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.current = testUser});

  AuthUser? current;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  String? lastSignInEmail;

  @override
  Future<AuthUser?> getSession() async => current;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastSignInEmail = email;
    if (email == 'fail@example.com') {
      throw const AuthException('Incorrect email or password.');
    }
    current = testUser;
    return testUser;
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (email == 'taken@example.com') {
      throw const AuthException('An account with this email already exists.');
    }
    current = testUser;
    return testUser;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }
}

/// In-memory onboarding repository. [completed] controls what the router
/// gate sees via `isCompleted`; tests that want a deterministic gate state
/// set `onboardingEvents.debugSet(...)` directly instead.
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = true});

  bool completed;
  int submitCalls = 0;
  OnboardingPayload? lastPayload;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> submit(OnboardingPayload payload) async {
    submitCalls++;
    lastPayload = payload;
  }
}

/// In-memory notebooks repository.
class FakeNotebooksRepository implements NotebooksRepository {
  final List<Notebook> notebooks = [];
  int _counter = 0;
  int chatCalls = 0;
  List<String> chatQuestions = [];
  bool failChat = false;

  @override
  Future<List<Notebook>> list() async => List.of(notebooks);

  @override
  Future<Notebook> create({required String title, String? description}) async {
    final n = Notebook(
      id: 'nb-${++_counter}',
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notebooks.insert(0, n);
    return n;
  }

  @override
  Future<void> delete(String id) async {
    notebooks.removeWhere((n) => n.id == id);
  }

  @override
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  }) async {
    chatCalls++;
    chatQuestions.add(question);
    if (failChat) {
      throw const NotebooksException(
        'The AI could not answer that. Try rephrasing the question.',
      );
    }
    return ChatReply(
      answer:
          'Photosynthesis converts light into chemical energy, as covered in your notes.',
      citations: const [
        ChatCitation(
          marker: 1,
          sourceId: 'src-1',
          sourceTitle: 'Biology Notes',
          page: 12,
          excerpt: 'Photosynthesis converts light energy into chemical energy.',
        ),
      ],
    );
  }

  final List<NotebookSource> sources = [];
  int _sourceCounter = 0;

  @override
  Future<List<NotebookSource>> listSources(String notebookId) async =>
      List.of(sources);

  @override
  Future<NotebookSource> addPastedSource(
    String notebookId, {
    required String title,
    required String text,
  }) async {
    final s = NotebookSource(
      id: 'src-${++_sourceCounter}',
      title: title,
      kind: 'pasted',
      status: SourceStatus.processing,
      wordCount: text.split(' ').length,
      createdAt: DateTime.now(),
    );
    sources.insert(0, s);
    return s;
  }
}

/// In-memory quizzes repository: quizzes, questions, and a controllable
/// scoring result.
class FakeQuizzesRepository implements QuizzesRepository {
  FakeQuizzesRepository({
    this.quizzes = const [],
    this.questions = const [],
    this.failGenerate = false,
    this.failList = false,
    this.failSubmit = false,
  });

  List<QuizSummary> quizzes;
  List<QuizQuestion> questions;
  bool failGenerate;
  bool failList;
  bool failSubmit;
  int generateCalls = 0;
  int submitCalls = 0;
  List<int>? lastAnswers;

  @override
  Future<List<QuizSummary>> list() async {
    if (failList) throw const QuizzesException('Could not load your quizzes.');
    return List.of(quizzes);
  }

  @override
  Future<QuizDetail> generate(
    String notebookId, {
    String? difficulty,
    int? count,
  }) async {
    generateCalls++;
    if (failGenerate) {
      throw const QuizzesException(
        'This notebook has no indexed sources yet. Add a source first.',
      );
    }
    final quiz = QuizSummary(
      id: 'quiz-${quizzes.length + 1}',
      title: 'Generated quiz',
      questionCount: questions.length,
      difficulty: difficulty ?? 'medium',
      notebookId: notebookId,
      createdAt: DateTime.now(),
    );
    quizzes = [quiz, ...quizzes];
    return QuizDetail(quiz: quiz, questions: List.of(questions));
  }

  @override
  Future<QuizDetail> quiz(String quizId) async {
    final quiz = quizzes.where((q) => q.id == quizId).firstOrNull;
    if (quiz == null) throw const QuizzesException('Could not load that quiz.');
    return QuizDetail(quiz: quiz, questions: List.of(questions));
  }

  @override
  Future<void> delete(String quizId) async {
    quizzes = quizzes.where((q) => q.id != quizId).toList();
  }

  @override
  Future<QuizResult> submit(String quizId, {required List<int> answers}) async {
    submitCalls++;
    lastAnswers = answers;
    if (failSubmit) {
      throw const QuizzesException('Could not score your answers.');
    }
    return QuizResult(
      score: 2,
      total: questions.length,
      percent: questions.isEmpty ? 0 : (2 / questions.length * 100).round(),
      perQuestion: [
        for (var i = 0; i < questions.length; i++)
          QuizAnswerResult(
            questionId: questions[i].id,
            question: questions[i].question,
            options: questions[i].options,
            selectedIndex: i < answers.length ? answers[i] : 0,
            correctIndex: questions[i].correctIndex,
            correct: i < answers.length
                ? answers[i] == questions[i].correctIndex
                : false,
            explanation: questions[i].explanation,
          ),
      ],
    );
  }
}

/// In-memory flashcards repository: decks and cards the tests control
/// directly, plus a record of review ratings posted.
class FakeFlashcardsRepository implements FlashcardsRepository {
  FakeFlashcardsRepository({
    this.decks = const [],
    this.cards = const [],
    this.failGenerate = false,
    this.failList = false,
  });

  List<FlashcardDeck> decks;
  List<Flashcard> cards;
  bool failGenerate;
  bool failList;
  final List<(String deckId, String cardId, int rating)> reviews = [];
  int generateCalls = 0;

  @override
  Future<List<FlashcardDeck>> list() async {
    if (failList) throw const FlashcardsException('Could not load your decks.');
    return List.of(decks);
  }

  @override
  Future<FlashcardDeckDetail> generate(
    String notebookId, {
    String? title,
  }) async {
    generateCalls++;
    if (failGenerate) {
      throw const FlashcardsException(
        'This notebook has no indexed sources yet. Add a source first.',
      );
    }
    final deck = FlashcardDeck(
      id: 'deck-${decks.length + 1}',
      title: title ?? 'Generated deck',
      cardCount: cards.length,
      notebookId: notebookId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    decks = [deck, ...decks];
    return FlashcardDeckDetail(deck: deck, cards: List.of(cards));
  }

  @override
  Future<FlashcardDeckDetail> deck(String deckId) async {
    final deck = decks.where((d) => d.id == deckId).firstOrNull;
    if (deck == null) {
      throw const FlashcardsException('Could not load that deck.');
    }
    return FlashcardDeckDetail(deck: deck, cards: List.of(cards));
  }

  @override
  Future<void> delete(String deckId) async {
    decks = decks.where((d) => d.id != deckId).toList();
  }

  @override
  Future<void> review(
    String deckId, {
    required String cardId,
    required int rating,
  }) async {
    reviews.add((deckId, cardId, rating));
  }

  FlashcardProgress progressData = const FlashcardProgress(
    totalReviews: 0,
    uniqueCards: 0,
    decks: [],
  );

  @override
  Future<FlashcardProgress> progress() async => progressData;
}

/// In-memory audio repository: episodes the tests control directly, with
/// an optional simulated background generation (create returns a
/// processing episode that flips to ready after [pollsUntilReady] polls).
class FakeAudioRepository implements AudioRepository {
  FakeAudioRepository({
    this.episodes = const [],
    this.pollsUntilReady = 0,
    this.failCreate = false,
  });

  List<AudioEpisode> episodes;
  int pollsUntilReady;
  bool failCreate;
  int createCalls = 0;
  int savePositionCalls = 0;
  List<int> savedPositions = [];
  String? lastStyle;
  String? lastLength;
  bool _createdProcessing = false;

  @override
  Future<List<AudioEpisode>> list() async => List.of(episodes);

  @override
  Future<AudioEpisode> create(
    String notebookId, {
    String style = 'focused',
    String length = 'standard',
  }) async {
    createCalls++;
    lastStyle = style;
    lastLength = length;
    if (failCreate) {
      throw const AudioException(
        'This notebook has no indexed sources yet. Add a source first.',
      );
    }
    final ready = pollsUntilReady <= 0;
    final episode = AudioEpisode(
      id: 'ep-${episodes.length + 1}',
      title: 'Generated podcast',
      style: style,
      length: length,
      status: ready ? 'ready' : 'processing',
      pipelineStage: ready ? 'ready' : 'organizing',
      audioUrl: '/api/audio/ep-${episodes.length + 1}/stream',
      createdAt: DateTime.now(),
      durationSec: 300,
      wordCount: 900,
      transcript: const [
        TranscriptSection(
          heading: 'Introduction',
          text: 'Welcome to your study session.',
          startSec: 0,
        ),
        TranscriptSection(
          heading: 'Core concepts',
          text: 'The key ideas are covered here.',
          startSec: 30,
          sources: ['Biology Notes'],
        ),
      ],
    );
    _createdProcessing = !ready;
    episodes = [episode, ...episodes];
    return episode;
  }

  @override
  Future<AudioEpisode> episode(String episodeId) async {
    final index = episodes.indexWhere((e) => e.id == episodeId);
    if (index < 0) throw const AudioException('Could not load that episode.');
    var e = episodes[index];
    if (e.isProcessing && _createdProcessing && pollsUntilReady > 0) {
      pollsUntilReady--;
      if (pollsUntilReady == 0) {
        e = e.copyWith(
          status: 'ready',
          pipelineStage: 'ready',
          durationSec: 300,
        );
        episodes[index] = e;
      }
    }
    return e;
  }

  @override
  Future<void> savePosition(String episodeId, int positionSec) async {
    savePositionCalls++;
    savedPositions.add(positionSec);
  }

  @override
  Future<void> delete(String episodeId) async {
    episodes = episodes.where((e) => e.id != episodeId).toList();
  }

  @override
  Future<Uint8List> download(
    String episodeId, {
    void Function(int, int?)? onProgress,
  }) async {
    return Uint8List.fromList(List.filled(64, 1)); // fake MP3 bytes
  }
}

/// Controllable podcast player fake.
class FakePodcastPlayer implements PodcastPlayer {
  Uint8List? loadedBytes;
  @override
  bool playing = false;
  @override
  double speed = 1.0;
  Duration? lastSeek;
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _completed = StreamController<void>.broadcast();

  void emitPosition(Duration d) => _position.add(d);

  @override
  Future<void> load(Uint8List bytes) async {
    loadedBytes = bytes;
    _duration.add(const Duration(seconds: 300));
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> seek(Duration position) async => lastSeek = position;

  @override
  Future<void> setSpeed(double value) async => speed = value;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _completed.close();
  }
}

/// In-memory study-planner repository: plans the tests control directly.
class FakeStudyPlannerRepository implements StudyPlannerRepository {
  FakeStudyPlannerRepository({this.plans = const []});

  List<StudyPlan> plans;
  bool failGenerate = false;
  int generateCalls = 0;
  int listCalls = 0;
  String? lastGeneratedExamId;

  @override
  Future<List<StudyPlan>> list() async {
    listCalls++;
    return List.of(plans);
  }

  @override
  Future<StudyPlan> generate(String examId) async {
    generateCalls++;
    lastGeneratedExamId = examId;
    if (failGenerate) {
      throw const StudyPlannerException('Could not build that plan.');
    }
    final plan = StudyPlan(
      id: 'plan-$examId',
      examId: examId,
      examTitle: 'Physics Midterm',
      version: 1,
      generatedForDate: todayKey(),
      tasks: [
        StudyPlanTask(
          id: 't-today',
          date: todayKey(),
          title: 'Review core concepts',
          detail: 'Work through your notes.',
          durationMin: 45,
          status: 'pending',
        ),
      ],
    );
    plans = [plan, ...plans.where((p) => p.examId != examId)];
    return plan;
  }

  @override
  Future<StudyPlan> updateTask(
    String planId, {
    required String taskId,
    required String status,
  }) async {
    final plan = plans.firstWhere((p) => p.id == planId);
    final updated = StudyPlan(
      id: plan.id,
      examId: plan.examId,
      examTitle: plan.examTitle,
      version: plan.version,
      generatedForDate: plan.generatedForDate,
      examDate: plan.examDate,
      tasks: [
        for (final t in plan.tasks)
          if (t.id == taskId) t.copyWith(status: status) else t,
      ],
    );
    plans = [
      for (final p in plans)
        if (p.id == planId) updated else p,
    ];
    return updated;
  }
}

/// yyyy-MM-dd for today in UTC (matches the backend's plan calendar).
String todayKey() {
  final d = DateTime.now().toUtc();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// In-memory dashboard repository: real-looking usage + exams the tests
/// control directly.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({
    this.currentUsage = const AiUsage(
      used: 3,
      limit: 20,
      remaining: 17,
      percent: 15,
      resetsAt: '',
      plan: 'free',
    ),
    this.currentExams = const [],
    this.failUsage = false,
  });

  AiUsage currentUsage;
  List<UpcomingExam> currentExams;
  bool failUsage;

  @override
  Future<AiUsage> usage() async {
    if (failUsage) throw const DashboardException('Could not load your usage.');
    return currentUsage;
  }

  @override
  Future<List<UpcomingExam>> exams() async => List.of(currentExams);
}

/// In-memory premium/billing repository: controllable plan, founding
/// status, price, and purchase outcome. The purchase result is whatever
/// the test sets it to — exactly how the real repository behaves after
/// the backend verification response — so tests can prove that a failed
/// verification never changes the plan (no client-side unlock).
class FakePlayBillingRepository implements PlayBillingRepository {
  FakePlayBillingRepository({
    this.plan = 'free',
    FoundingStatus? founding,
    this.priceLabel = '\$2',
    this.purchaseResult = const PurchaseResult(ok: true, plan: 'founding_member'),
    this.restoredPlans = const [],
  }) : founding = founding ??
           const FoundingStatus(
             offerActive: true,
             claimed: 12,
             cap: 35,
             available: true,
             remaining: 23,
           );

  String plan;
  FoundingStatus founding;
  String? priceLabel;
  PurchaseResult purchaseResult;
  List<String> restoredPlans;
  bool playSupportedOverride = false;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  int statusCalls = 0;

  @override
  bool get playBillingSupported => playSupportedOverride;

  @override
  Future<FoundingStatus> foundingStatus() async {
    statusCalls++;
    return founding;
  }

  @override
  Future<String> currentPlan() async => plan;

  @override
  Future<String?> foundingPriceLabel() async => priceLabel;

  @override
  Future<PurchaseResult> purchaseFounding() async {
    purchaseCalls++;
    // Mirrors the real flow: the backend verifies the token and the next
    // plan fetch reflects the granted entitlement. A failed verification
    // leaves the plan untouched.
    if (purchaseResult.ok && purchaseResult.plan != null) {
      plan = purchaseResult.plan!;
    }
    return purchaseResult;
  }

  @override
  Future<List<String>> restorePurchases() async {
    restoreCalls++;
    return restoredPlans;
  }

  @override
  Future<String> webCheckoutUrl() async => 'https://checkout.example.com/session';
}

/// Pump the app router with fake repositories. When [signedIn] is true
/// the router starts authenticated (skipping the splash/login); when
/// false it lands on /login. Returns the auth fake for assertions.
Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  GoRouter? router,
  FakeAuthRepository? auth,
  NotebooksRepository? notebooks,
  OnboardingRepository? onboarding,
  FakeDashboardRepository? dashboard,
  FlashcardsRepository? flashcards,
  QuizzesRepository? quizzes,
  FakeAudioRepository? audio,
  FakePodcastPlayer? podcastPlayer,
  FakeStudyPlannerRepository? planner,
  FakePlayBillingRepository? premium,
  OnboardingStatus? onboardingStatus,
  bool signedIn = true,
  Size size = const Size(390, 844),

  /// Pin the rendering-performance tier (overrides auto-detection). When
  /// null the real [performanceTierProvider] chain runs: auto-detection,
  /// with the manual Settings → Reduce visual effects switch winning.
  PerformanceTier? tier,
}) async {
  authEvents.reset();
  onboardingEvents.reset();
  if (onboardingStatus != null) {
    onboardingEvents.debugSet(onboardingStatus);
  }
  final authFake =
      auth ?? FakeAuthRepository(current: signedIn ? testUser : null);
  authEvents.debugSet(
    signedIn
        ? AuthAuthenticated(authFake.current ?? testUser)
        : const AuthUnauthenticated(),
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authFake),
        onboardingRepositoryProvider.overrideWithValue(
          onboarding ?? FakeOnboardingRepository(),
        ),
        dashboardRepositoryProvider.overrideWithValue(
          dashboard ?? FakeDashboardRepository(),
        ),
        notebooksRepositoryProvider.overrideWithValue(
          notebooks ?? FakeNotebooksRepository(),
        ),
        flashcardsRepositoryProvider.overrideWithValue(
          flashcards ?? FakeFlashcardsRepository(),
        ),
        quizzesRepositoryProvider.overrideWithValue(
          quizzes ?? FakeQuizzesRepository(),
        ),
        audioRepositoryProvider.overrideWithValue(
          audio ?? FakeAudioRepository(),
        ),
        podcastPlayerProvider.overrideWithValue(
          podcastPlayer ?? FakePodcastPlayer(),
        ),
        studyPlannerRepositoryProvider.overrideWithValue(
          planner ?? FakeStudyPlannerRepository(),
        ),
        playBillingRepositoryProvider.overrideWithValue(
          premium ?? FakePlayBillingRepository(),
        ),
        if (tier != null) performanceTierProvider.overrideWithValue(tier),
      ],
      child: _TestApp(router: router ?? buildAppRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return authFake;
}

/// Mirrors production's MaterialApp (light + dark themes, user theme mode
/// from Settings → Appearance) so theme behavior is exercised in tests.
class _TestApp extends ConsumerWidget {
  const _TestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: router,
      theme: buildAppTheme(
        Brightness.light,
        tier: ref.watch(performanceTierProvider),
      ),
      darkTheme: buildAppTheme(
        Brightness.dark,
        tier: ref.watch(performanceTierProvider),
      ),
      themeMode: ref.watch(themeModeProvider),
    );
  }
}
