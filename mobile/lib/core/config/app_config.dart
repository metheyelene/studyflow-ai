/// Static app configuration.
///
/// The backend origin defaults to the local dev server. Override at build
/// time with `--dart-define=API_BASE_URL=https://api.example.com`.
/// Note: the Android emulator reaches the host machine at
/// `http://10.0.2.2:<port>`, not `127.0.0.1`.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3100',
  );

  /// Better-auth session cookie (cookiePrefix "studyflow" + session_token).
  static const String sessionCookieName = 'studyflow.session_token';

  /// Secure-storage key for the persisted session token.
  static const String sessionTokenStorageKey = 'studyflow.session_token';
}
