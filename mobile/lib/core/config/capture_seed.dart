/// Seed data + in-memory repositories for CAPTURE_MODE builds. The app
/// boots signed in with obvious sample content (deliberately "Sample:"
/// prefixed, per the Play Store listing guide — a reviewer must never
/// mistake marketing screenshots for a real user's data).
///
/// The signed-in flag is kept in localStorage so it survives full page
/// reloads between screenshots (the driver navigates with page.goto, which
/// reloads the app).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture_storage.dart';
import '../../features/authentication/auth_models.dart';
import '../../features/authentication/auth_repository.dart';
import '../../features/notebooks/note_assist.dart';
import '../../features/notebooks/notebook.dart';
import '../../features/notebooks/notebook_chat.dart';
import '../../features/notebooks/notebook_sources.dart';
import '../../features/notebooks/notebooks_repository.dart';
import '../../features/notebooks/source_upload.dart';
import '../../features/premium/play_billing_repository.dart';
import '../../features/premium/premium_models.dart';

import 'dart:typed_data';

import '../../features/audio/audio_models.dart';
import '../../features/audio/audio_repository.dart';
import '../../features/flashcards/flashcard_models.dart';
import '../../features/flashcards/flashcards_repository.dart';
import '../../features/quizzes/quiz_models.dart';
import '../../features/quizzes/quizzes_repository.dart';

import '../../features/onboarding/onboarding_models.dart';
import '../../features/onboarding/onboarding_repository.dart';
import '../../features/dashboard/dashboard_repository.dart';

final captureUser = AuthUser(
  id: 'capture-user',
  name: 'Aarav Sharma',
  email: 'aarav@example.com',
);

class _CaptureAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> getSession() async =>
      captureSignedIn() ? captureUser : null;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    captureSetSignedIn(true);
    return captureUser;
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => captureUser;

  @override
  Future<void> signOut() async {}
}

/// Dashboard data for capture builds: a realistic free-plan usage state
/// (17 of 20 AI actions left) and one sample upcoming exam so the Home
/// hero and countdown card render instead of erroring on the dead API.
class _CaptureDashboardRepository implements DashboardRepository {
  @override
  Future<AiUsage> usage() async => const AiUsage(
    used: 3,
    limit: 20,
    remaining: 17,
    percent: 15,
    resetsAt: '',
    plan: 'free',
  );

  @override
  Future<List<UpcomingExam>> exams() async {
    final d = DateTime.now().add(const Duration(days: 21));
    final iso =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return [
      UpcomingExam(
        id: 'capture-exam-1',
        title: 'Sample: Electromagnetics Midterm',
        date: iso,
      ),
    ];
  }
}

/// Capture builds are signed in but must not gate on onboarding — the
/// backend isn't reachable and the screenshots target the app shell.
class _CaptureOnboardingRepository implements OnboardingRepository {
  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> submit(OnboardingPayload payload) async {}
}

class CaptureNotebooksRepository implements NotebooksRepository {
  CaptureNotebooksRepository({List<Notebook>? seed})
    : _notebooks = seed ?? _sampleNotebooks();

  final List<Notebook> _notebooks;
  int _counter = 100;

  static List<Notebook> _sampleNotebooks() {
    final now = DateTime.now();
    Notebook nb(
      String id,
      String title,
      String desc,
      int sources,
      int daysAgo,
    ) => Notebook(
      id: id,
      title: title,
      description: desc,
      createdAt: now.subtract(Duration(days: daysAgo + 7)),
      updatedAt: now.subtract(Duration(days: daysAgo)),
      sourceCount: sources,
    );
    return [
      nb(
        'nb-cell-bio',
        'Sample: Cell Biology — Unit 2',
        'Photosynthesis & respiration notes',
        3,
        0,
      ),
      nb('nb-vlsi', 'Sample: VLSI Unit 3', 'CMOS design lecture notes', 5, 2),
      nb(
        'nb-chem',
        'Sample: Organic Chemistry',
        'Reaction mechanisms + named reactions',
        2,
        5,
      ),
    ];
  }

  @override
  Future<List<Notebook>> list() async => List.of(_notebooks);

  @override
  Future<Notebook> create({required String title, String? description}) async {
    final n = Notebook(
      id: 'nb-${_counter++}',
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _notebooks.insert(0, n);
    return n;
  }

  @override
  Future<void> delete(String id) async {
    _notebooks.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<NotebookSource>> listSources(String notebookId) async {
    return [
      NotebookSource(
        id: 'src-1',
        title: 'Sample: Photosynthesis notes',
        kind: 'pasted',
        status: SourceStatus.ready,
        wordCount: 240,
        createdAt: DateTime(2026),
      ),
    ];
  }

  @override
  Future<NotebookSource> addPastedSource(
    String notebookId, {
    required String title,
    required String text,
  }) async {
    return NotebookSource(
      id: 'src-new',
      title: title,
      kind: 'pasted',
      status: SourceStatus.processing,
      wordCount: text.split(' ').length,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<NotebookSource>> uploadFiles(
    String notebookId, {
    required List<UploadFile> files,
    void Function(int done, int total)? onProgress,
  }) async {
    onProgress?.call(files.length, files.length);
    return [
      for (var i = 0; i < files.length; i++)
        NotebookSource(
          id: 'src-up-$i',
          title: files[i].name,
          kind: 'uploaded',
          status: SourceStatus.processing,
          sizeBytes: files[i].bytes.length,
          createdAt: DateTime.now(),
        ),
    ];
  }

  @override
  Future<void> deleteSource(String notebookId, String sourceId) async {
    // The capture seed is a canned preview — sources are not stored
    // locally, so there is nothing to remove.
  }

  @override
  Future<String> assistText(
    String notebookId, {
    required NoteAssistMode mode,
    required String text,
  }) async {
    // Capture builds have no backend, so the toolbar returns a labeled
    // sample so the flow stays demoable.
    return '${mode.label}: sample response for “$text” (capture build).';
  }

  @override
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  }) async {
    return ChatReply(
      answer:
          'Sample answer: based on your sources, this is the key idea. '
          'It is stated in your lecture notes.',
      citations: const [
        ChatCitation(
          marker: 1,
          sourceId: 'src-1',
          sourceTitle: 'Sample: Cell Biology — Unit 2',
          page: 4,
          excerpt: 'Photosynthesis converts light energy into chemical energy.',
        ),
      ],
    );
  }
}

/// Flashcard decks, quizzes, and audio episodes for capture builds.
/// The app has no backend in CAPTURE_MODE, so these repositories return
/// clearly-labeled sample data ("Sample:" prefixes keep the store shots
/// honest) so the study screens render instead of erroring.
class _CaptureFlashcardsRepository implements FlashcardsRepository {
  List<FlashcardDeck> get _decks {
    final now = DateTime(2026, 8, 11);
    return [
      FlashcardDeck(
        id: 'fc-photosynthesis',
        title: 'Sample: Photosynthesis deck',
        cardCount: 12,
        notebookId: 'nb-cell-bio',
        createdAt: now,
        updatedAt: now,
      ),
      FlashcardDeck(
        id: 'fc-vlsi',
        title: 'Sample: VLSI CMOS deck',
        cardCount: 18,
        notebookId: 'nb-vlsi',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<FlashcardDeck>> list() async => _decks;

  @override
  Future<FlashcardDeckDetail> generate(
    String notebookId, {
    String? title,
  }) async => _detail('fc-photosynthesis');

  @override
  Future<FlashcardDeckDetail> deck(String deckId) async => _detail(deckId);

  FlashcardDeckDetail _detail(String deckId) {
    final deck = _decks.firstWhere(
      (d) => d.id == deckId,
      orElse: () => _decks.first,
    );
    return FlashcardDeckDetail(
      deck: deck,
      cards: const [
        Flashcard(
          id: 'c1',
          front: 'What does a CMOS inverter consist of?',
          back: 'A PMOS pull-up and an NMOS pull-down transistor in series.',
        ),
        Flashcard(
          id: 'c2',
          front: 'What is the switching threshold?',
          back: 'The input voltage where the output crosses the midpoint.',
        ),
        Flashcard(
          id: 'c3',
          front: 'Name the two power rails.',
          back: 'VDD (supply) and VSS (ground).',
        ),
        Flashcard(
          id: 'c4',
          front: 'What causes static power in CMOS?',
          back: 'Leakage currents while the circuit is idle.',
        ),
      ],
    );
  }

  @override
  Future<void> delete(String deckId) async {}

  @override
  Future<void> review(
    String deckId, {
    required String cardId,
    required int rating,
  }) async {}

  @override
  Future<FlashcardProgress> progress() async => const FlashcardProgress(
    totalReviews: 42,
    uniqueCards: 24,
    decks: [
      DeckAccuracy(
        deckId: 'fc-photosynthesis',
        title: 'Sample: Photosynthesis deck',
        reviews: 26,
        remembered: 19,
        accuracy: 73,
      ),
      DeckAccuracy(
        deckId: 'fc-vlsi',
        title: 'Sample: VLSI CMOS deck',
        reviews: 16,
        remembered: 13,
        accuracy: 81,
      ),
    ],
  );
}

class _CaptureQuizzesRepository implements QuizzesRepository {
  QuizSummary get _summary => QuizSummary(
    id: 'qz-photosynthesis',
    title: 'Sample: Photosynthesis quiz',
    questionCount: 8,
    difficulty: 'medium',
    notebookId: 'nb-cell-bio',
    attempts: 2,
    bestScore: 6,
    bestTotal: 8,
    createdAt: DateTime(2026, 8, 10),
  );

  @override
  Future<List<QuizSummary>> list() async => [
    _summary,
    QuizSummary(
      id: 'qz-vlsi',
      title: 'Sample: VLSI Unit 3 quiz',
      questionCount: 10,
      difficulty: 'hard',
      notebookId: 'nb-vlsi',
      attempts: 1,
      bestScore: 7,
      bestTotal: 10,
      createdAt: DateTime(2026, 8, 9),
    ),
  ];

  @override
  Future<QuizDetail> generate(
    String notebookId, {
    String? difficulty,
    int? count,
  }) async => _detail('qz-photosynthesis');

  @override
  Future<QuizDetail> quiz(String quizId) async => _detail(quizId);

  QuizDetail _detail(String quizId) => QuizDetail(
    quiz: _summary,
    questions: const [
      QuizQuestion(
        id: 'q1',
        question: 'Where does the light-dependent reaction take place?',
        options: ['Thylakoid membrane', 'Stroma', 'Mitochondria', 'Cytoplasm'],
        correctIndex: 0,
        explanation: 'Light energy is captured in the thylakoid membrane.',
      ),
      QuizQuestion(
        id: 'q2',
        question: 'What is the primary product of the Calvin cycle?',
        options: ['Glucose', 'G3P', 'Oxygen', 'ATP'],
        correctIndex: 1,
        explanation: 'The Calvin cycle fixes CO₂ into G3P.',
      ),
      QuizQuestion(
        id: 'q3',
        question: 'Which pigment absorbs most red and blue light?',
        options: [
          'Chlorophyll a',
          'Carotene',
          'Xanthophyll',
          'Phycoerythrin',
        ],
        correctIndex: 0,
        explanation: 'Chlorophyll a is the primary photosynthetic pigment.',
      ),
    ],
  );

  @override
  Future<void> delete(String quizId) async {}

  @override
  Future<QuizResult> submit(
    String quizId, {
    required List<int> answers,
  }) async => const QuizResult(
    score: 3,
    total: 3,
    percent: 100,
    perQuestion: [],
  );
}

class _CaptureAudioRepository implements AudioRepository {
  List<AudioEpisode> get _episodes {
    final now = DateTime(2026, 8, 11);
    return [
      AudioEpisode(
        id: 'ep-cell-bio',
        title: 'Sample: Cell Biology Study Podcast',
        style: 'podcast',
        length: 'standard',
        status: 'ready',
        pipelineStage: 'ready',
        audioUrl: '',
        createdAt: now,
        notebookId: 'nb-cell-bio',
        notebookTitle: 'Sample: Cell Biology — Unit 2',
        durationSec: 1020,
        wordCount: 1240,
        transcript: const [
          TranscriptSection(
            heading: 'Introduction',
            text: 'This episode walks through photosynthesis.',
            startSec: 0,
          ),
        ],
      ),
      AudioEpisode(
        id: 'ep-vlsi',
        title: 'Sample: VLSI Unit 3 Deep Dive',
        style: 'deep',
        length: 'deep',
        status: 'ready',
        pipelineStage: 'ready',
        audioUrl: '',
        createdAt: now.subtract(const Duration(days: 2)),
        notebookId: 'nb-vlsi',
        notebookTitle: 'Sample: VLSI Unit 3',
        durationSec: 1560,
        wordCount: 1890,
        transcript: const [
          TranscriptSection(
            heading: 'CMOS overview',
            text: 'The inverter is the building block of digital logic.',
            startSec: 0,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<AudioEpisode>> list() async => _episodes;

  @override
  Future<AudioEpisode> create(
    String notebookId, {
    String style = 'podcast',
    String length = 'standard',
  }) async => _episodes.first;

  @override
  Future<AudioEpisode> episode(String episodeId) async =>
      _episodes.firstWhere(
        (e) => e.id == episodeId,
        orElse: () => _episodes.first,
      );

  @override
  Future<void> savePosition(String episodeId, int positionSec) async {}

  @override
  Future<void> delete(String episodeId) async {}

  @override
  Future<Uint8List> download(
    String episodeId, {
    void Function(int, int?)? onProgress,
  }) async => Uint8List(0);
}

/// Premium/billing snapshot for capture builds: free plan with the
/// founding-member offer active so the offer card renders.
class _CapturePlayBillingRepository implements PlayBillingRepository {
  @override
  bool get playBillingSupported => false;

  @override
  Future<FoundingStatus> foundingStatus() async => const FoundingStatus(
    offerActive: true,
    claimed: 21,
    cap: 35,
    available: true,
    remaining: 14,
  );

  @override
  Future<String> currentPlan() async => 'free';

  @override
  Future<String?> foundingPriceLabel() async => null;

  @override
  Future<PurchaseResult> purchaseFounding() async => const PurchaseResult(
    ok: false,
    plan: null,
    message: null,
  );

  @override
  Future<List<String>> restorePurchases() async => const [];

  @override
  Future<String> webCheckoutUrl() async => '';
}

/// Riverpod overrides that make a capture build fully self-contained.
final captureOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(_CaptureAuthRepository()),
  onboardingRepositoryProvider.overrideWithValue(
    _CaptureOnboardingRepository(),
  ),
  notebooksRepositoryProvider.overrideWithValue(CaptureNotebooksRepository()),
  dashboardRepositoryProvider.overrideWithValue(_CaptureDashboardRepository()),
  flashcardsRepositoryProvider.overrideWithValue(
    _CaptureFlashcardsRepository(),
  ),
  quizzesRepositoryProvider.overrideWithValue(_CaptureQuizzesRepository()),
  audioRepositoryProvider.overrideWithValue(_CaptureAudioRepository()),
  playBillingRepositoryProvider.overrideWithValue(
    _CapturePlayBillingRepository(),
  ),
];
