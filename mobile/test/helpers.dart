import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
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
import 'package:studyflow_mobile/features/onboarding/onboarding_models.dart';
import 'package:studyflow_mobile/features/onboarding/onboarding_repository.dart';

const testUser = AuthUser(id: 'user_1', name: 'Test User', email: 'test@example.com');

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
  Future<AuthUser> signIn({required String email, required String password}) async {
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
      throw const NotebooksException('The AI could not answer that. Try rephrasing the question.');
    }
    return ChatReply(
      answer: 'Photosynthesis converts light into chemical energy, as covered in your notes.',
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
  Future<List<NotebookSource>> listSources(String notebookId) async => List.of(sources);

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
  Future<QuizDetail> generate(String notebookId, {String? difficulty, int? count}) async {
    generateCalls++;
    if (failGenerate) {
      throw const QuizzesException('This notebook has no indexed sources yet. Add a source first.');
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
    if (failSubmit) throw const QuizzesException('Could not score your answers.');
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
            correct: i < answers.length ? answers[i] == questions[i].correctIndex : false,
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
  Future<FlashcardDeckDetail> generate(String notebookId, {String? title}) async {
    generateCalls++;
    if (failGenerate) {
      throw const FlashcardsException('This notebook has no indexed sources yet. Add a source first.');
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
    if (deck == null) throw const FlashcardsException('Could not load that deck.');
    return FlashcardDeckDetail(deck: deck, cards: List.of(cards));
  }

  @override
  Future<void> delete(String deckId) async {
    decks = decks.where((d) => d.id != deckId).toList();
  }

  @override
  Future<void> review(String deckId, {required String cardId, required int rating}) async {
    reviews.add((deckId, cardId, rating));
  }
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
  OnboardingStatus? onboardingStatus,
  bool signedIn = true,
  Size size = const Size(390, 844),
}) async {
  authEvents.reset();
  onboardingEvents.reset();
  if (onboardingStatus != null) {
    onboardingEvents.debugSet(onboardingStatus);
  }
  final authFake = auth ?? FakeAuthRepository(current: signedIn ? testUser : null);
  authEvents.debugSet(signedIn ? const AuthAuthenticated(testUser) : const AuthUnauthenticated());

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authFake),
        onboardingRepositoryProvider.overrideWithValue(onboarding ?? FakeOnboardingRepository()),
        dashboardRepositoryProvider.overrideWithValue(dashboard ?? FakeDashboardRepository()),
        notebooksRepositoryProvider.overrideWithValue(notebooks ?? FakeNotebooksRepository()),
        flashcardsRepositoryProvider.overrideWithValue(flashcards ?? FakeFlashcardsRepository()),
        quizzesRepositoryProvider.overrideWithValue(quizzes ?? FakeQuizzesRepository()),
      ],
      child: MaterialApp.router(
        routerConfig: router ?? buildAppRouter(),
        theme: buildAppTheme(Brightness.light),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return authFake;
}
