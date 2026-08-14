/// Static app + creator information. Only the details the creator has
/// explicitly provided live here — nothing invented, no extra personal
/// data. Email appears solely as a mailto contact, never in metadata.
library;

abstract final class AppInfo {
  static const String appName = 'StudyFlow AI';
  static const String tagline =
      'An AI-powered study workspace designed to help students turn their '
      'learning material into a more organized and interactive study experience.';

  static const String creatorName = 'Mithil Viswas Kasi';
  static const String creatorRole = 'Creator & Developer of StudyFlow AI';
  static const String creatorQuote =
      'Built with the goal of making studying more organized, interactive, and intelligent.';
  static const String creatorEmail = 'mithilviswask@gmail.com';
  static const String feedbackSubject = 'StudyFlow AI — Feedback';

  /// Founder identity. The mobile app shows the founder-dashboard entry
  /// only to this account; it must match the backend's ADMIN_EMAILS env
  /// (the real security boundary lives server-side on /admin).
  static const String founderEmail = creatorEmail;

  static const List<String> features = [
    'Source-grounded AI study assistance',
    'Smart notes',
    'Flashcards',
    'Quizzes',
    'Study planning',
    'Progress tracking',
  ];
}
