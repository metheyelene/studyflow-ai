import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/authentication/auth_controller.dart';
import 'package:studyflow_mobile/features/authentication/auth_models.dart';
import 'package:studyflow_mobile/features/authentication/auth_repository.dart';
import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';

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

/// In-memory notebooks repository.
class FakeNotebooksRepository implements NotebooksRepository {
  final List<Notebook> notebooks = [];
  int _counter = 0;

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
}

/// Pump the app router with fake repositories. When [signedIn] is true
/// the router starts authenticated (skipping the splash/login); when
/// false it lands on /login. Returns the auth fake for assertions.
Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  GoRouter? router,
  FakeAuthRepository? auth,
  NotebooksRepository? notebooks,
  bool signedIn = true,
  Size size = const Size(390, 844),
}) async {
  authEvents.reset();
  final authFake = auth ?? FakeAuthRepository(current: signedIn ? testUser : null);
  authEvents.debugSet(signedIn ? const AuthAuthenticated(testUser) : const AuthUnauthenticated());

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authFake),
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
