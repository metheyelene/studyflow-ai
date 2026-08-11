import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'onboarding_models.dart';

/// Friendly, user-safe error for onboarding failures — never raw HTTP text.
class OnboardingException implements Exception {
  const OnboardingException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class OnboardingRepository {
  /// Whether the signed-in user has completed onboarding
  /// (GET /api/onboarding).
  Future<bool> isCompleted();

  /// Persist a completed onboarding (POST /api/onboarding — idempotent,
  /// safe to re-run if the user edits their answers later).
  Future<void> submit(OnboardingPayload payload);
}

/// REST implementation against the shared backend route. The backend is
/// the source of truth for validation; the client only sends the same
/// shape the web form posts.
class ApiOnboardingRepository implements OnboardingRepository {
  ApiOnboardingRepository(this._client);

  final ApiClient _client;

  @override
  Future<bool> isCompleted() async {
    final res = await _client.get<dynamic>('/api/onboarding');
    final data = res.data;
    if (data is! Map) return false;
    return data['onboardingCompleted'] == true;
  }

  @override
  Future<void> submit(OnboardingPayload payload) async {
    try {
      await _client.post<dynamic>('/api/onboarding', data: payload.toJson());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['error']
          : null;
      final friendly = switch (status) {
        400 || 422 => (message is String && message.isNotEmpty)
            ? message
            : 'Please fill in every field to continue.',
        401 => 'Your session expired. Please log in again.',
        null => 'Could not reach the server. Check your connection and try again.',
        _ => 'Something went wrong. Please try again.',
      };
      throw OnboardingException(friendly);
    }
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => ApiOnboardingRepository(ref.watch(apiClientProvider)),
);
