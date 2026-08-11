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
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_chat.dart';
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
