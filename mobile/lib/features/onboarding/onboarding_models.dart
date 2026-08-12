/// Onboarding models. The payload mirrors the web form exactly so the
/// backend's shared `completeOnboarding` validator (src/lib/onboarding.ts)
/// treats mobile and web submissions identically.
library;

/// Whether the signed-in user has completed onboarding. `unknown` while
/// the status hasn't been fetched yet (or the fetch failed — the router
/// never gates on `unknown`, so a network hiccup can't strand a user).
enum OnboardingStatus { unknown, needed, done }

/// One exam the user is preparing for. The date is required; the name is
/// optional (the backend falls back to the course name).
class OnboardingExam {
  const OnboardingExam({this.name, required this.date});

  final String? name;
  final String date; // yyyy-MM-dd
}

/// Payload for POST /api/onboarding.
class OnboardingPayload {
  const OnboardingPayload({
    required this.course,
    required this.subjects,
    required this.exams,
    required this.dailyMinutes,
    required this.goals,
  });

  /// What the user is studying (e.g. "Medicine").
  final String course;

  /// Comma-separated subject names (up to 5 on the backend).
  final String subjects;

  /// Up to 3 exams.
  final List<OnboardingExam> exams;

  /// Daily study minutes (backend accepts 5–480).
  final int dailyMinutes;

  /// Goal values matching the backend's GOAL_OPTIONS.
  final List<String> goals;

  Map<String, dynamic> toJson() => {
    'course': course,
    'subjects': subjects,
    'exams': [
      for (final e in exams) {'name': e.name ?? '', 'date': e.date},
    ],
    'dailyMinutes': dailyMinutes,
    'goals': goals,
  };
}
