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

  static const List<String> features = [
    'Source-grounded AI study assistance',
    'Smart notes',
    'Flashcards',
    'Quizzes',
    'Study planning',
    'Progress tracking',
  ];
}
