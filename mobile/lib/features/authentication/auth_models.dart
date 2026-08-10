/// A signed-in user (subset of the server session).
class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}

/// Router-facing auth state, also mirrored into the Riverpod
/// [AuthController] for widgets.
sealed class AuthState {
  const AuthState();
}

/// Restoring the session on boot — show the splash.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}
