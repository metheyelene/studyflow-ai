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

  /// Screenshot-capture mode (`--dart-define=CAPTURE_MODE=true`). Boots the
  /// app signed in with seeded sample notebooks and exposes the semantics
  /// tree, so the capture driver (mobile/tool/capture_screenshots.sh) can
  /// click real widgets and produce Play Store phone screenshots without a
  /// live backend. Only ever set for screenshot builds — never in release.
  static const bool captureMode = bool.fromEnvironment(
    'CAPTURE_MODE',
    defaultValue: false,
  );

  /// The web app origin (Next.js), used for links from the app — e.g. the
  /// founder dashboard at `<webAppUrl>/admin`. Override with
  /// `--dart-define=WEB_APP_URL=https://studyflow-ai.vercel.app`.
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Better-auth session cookie (cookiePrefix "studyflow" + session_token).
  static const String sessionCookieName = 'studyflow.session_token';

  /// Secure-storage key for the persisted session token.
  static const String sessionTokenStorageKey = 'studyflow.session_token';
}
