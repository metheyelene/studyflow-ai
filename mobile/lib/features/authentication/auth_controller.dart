import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_controller.dart';
import '../notebooks/notebooks_controller.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_models.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// Router-facing auth store. The global [appRouter] uses this as its
/// `refreshListenable` and reads [state] synchronously inside `redirect`,
/// so login/logout/session-restore navigation happens automatically.
/// [AuthController] mirrors it into Riverpod for widgets.
class AuthEvents extends ChangeNotifier {
  AuthEvents(this._state);

  AuthState _state;
  AuthState get state => _state;

  void set(AuthState next) {
    _state = next;
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(AuthState next) {
    _state = next;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _state = const AuthInitializing();
    notifyListeners();
  }
}

/// The app's single auth store instance.
final AuthEvents authEvents = AuthEvents(const AuthInitializing());

/// Auth flow orchestration. Screens watch [authControllerProvider] for the
/// current [AuthState]; the store keeps the router in sync. Sign-in/up
/// return a friendly error string, or null on success.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    authEvents.addListener(_sync);
    ref.onDispose(() => authEvents.removeListener(_sync));
    return authEvents.state;
  }

  void _sync() {
    state = authEvents.state;
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Re-attach the persisted token and validate it against the server.
  Future<void> restore() async {
    final user = await _repo.getSession();
    _resetUserScopedState();
    authEvents.set(
      user == null ? const AuthUnauthenticated() : AuthAuthenticated(user),
    );
    if (user != null) await _refreshOnboarding();
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repo.signIn(email: email, password: password);
      _resetUserScopedState();
      authEvents.set(AuthAuthenticated(user));
      await _refreshOnboarding();
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repo.signUp(
        name: name,
        email: email,
        password: password,
      );
      _resetUserScopedState();
      authEvents.set(AuthAuthenticated(user));
      await _refreshOnboarding();
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _resetUserScopedState();
    onboardingEvents.set(OnboardingStatus.unknown);
    authEvents.set(const AuthUnauthenticated());
  }

  /// Drop cached, user-scoped state so a different account (or a fresh
  /// sign-out) never sees the previous user's data. Providers refetch on
  /// the next screen build.
  void _resetUserScopedState() {
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(notebooksControllerProvider);
    ref.invalidate(notebookChatControllerProvider);
  }

  /// Fetch the onboarding gate state for the newly authenticated user. The
  /// router redirects to /onboarding until this resolves; on failure the
  /// status stays `unknown` and the user enters the app normally.
  Future<void> _refreshOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).refresh();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
