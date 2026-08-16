import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';

/// The ONLY AI configuration the app exposes. Providers, keys, models, and
/// endpoints are server-side concerns the user never sees — these three
/// product-level preferences shape every generation.
enum AiResponseStyle { concise, balanced, detailed }

enum AiStudyLevel { school, university, professional }

class AiPreferences {
  const AiPreferences({
    this.responseStyle = AiResponseStyle.balanced,
    this.studyLevel = AiStudyLevel.university,
    this.language = 'English',
  });

  final AiResponseStyle responseStyle;
  final AiStudyLevel studyLevel;
  final String language;

  factory AiPreferences.fromJson(Map<String, dynamic> json) {
    return AiPreferences(
      responseStyle: switch (json['responseStyle']) {
        'concise' => AiResponseStyle.concise,
        'detailed' => AiResponseStyle.detailed,
        _ => AiResponseStyle.balanced,
      },
      studyLevel: switch (json['studyLevel']) {
        'school' => AiStudyLevel.school,
        'professional' => AiStudyLevel.professional,
        _ => AiStudyLevel.university,
      },
      language: json['language'] as String? ?? 'English',
    );
  }

  Map<String, dynamic> toJson() => {
    'responseStyle': responseStyle.name,
    'studyLevel': studyLevel.name,
    'language': language,
  };

  AiPreferences copyWith({
    AiResponseStyle? responseStyle,
    AiStudyLevel? studyLevel,
    String? language,
  }) {
    return AiPreferences(
      responseStyle: responseStyle ?? this.responseStyle,
      studyLevel: studyLevel ?? this.studyLevel,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiPreferences &&
      other.responseStyle == responseStyle &&
      other.studyLevel == studyLevel &&
      other.language == language;

  @override
  int get hashCode => Object.hash(responseStyle, studyLevel, language);
}

class AiPreferencesException implements Exception {
  const AiPreferencesException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Seam for the backend AI-preferences endpoint. The app never touches a
/// provider — it only reads/writes these three preferences.
abstract class AiPreferencesRepository {
  Future<AiPreferences> load();

  Future<void> save(AiPreferences preferences);
}

class ApiAiPreferencesRepository implements AiPreferencesRepository {
  ApiAiPreferencesRepository(this._client);

  final ApiClient _client;

  @override
  Future<AiPreferences> load() async {
    final res = await _client.get<dynamic>('/api/profile/ai-preferences');
    final data = res.data;
    final prefs = data is Map ? data['preferences'] : null;
    if (prefs is! Map) {
      throw const AiPreferencesException('Could not load your AI preferences.');
    }
    return AiPreferences.fromJson(Map<String, dynamic>.from(prefs));
  }

  @override
  Future<void> save(AiPreferences preferences) async {
    await _client.put<dynamic>(
      '/api/profile/ai-preferences',
      data: preferences.toJson(),
    );
  }
}

final aiPreferencesRepositoryProvider = Provider<AiPreferencesRepository>(
  (ref) => ApiAiPreferencesRepository(ref.watch(apiClientProvider)),
);

/// Loads the user's AI preferences lazily (when the Settings section is
/// first expanded). The screen applies optimistic local updates via
/// [AiPreferencesController.set]; the repository save is the server-side
/// source of truth.
class AiPreferencesController extends AsyncNotifier<AiPreferences> {
  @override
  Future<AiPreferences> build() =>
      ref.watch(aiPreferencesRepositoryProvider).load();

  void set(AiPreferences preferences) => state = AsyncData(preferences);
}

final aiPreferencesControllerProvider =
    AsyncNotifierProvider<AiPreferencesController, AiPreferences>(
      AiPreferencesController.new,
    );
