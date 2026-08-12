import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'auth_models.dart';

/// Friendly, user-safe error for auth failures — never raw HTTP text.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Restore the session: re-attach the persisted token and validate it.
  Future<AuthUser?> getSession();

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// better-auth implementation (cookie-based sessions, endpoints under
/// /api/auth/*). The session token is persisted in secure storage so a
/// restart restores the session without re-entering credentials.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final ApiClient _client;

  AuthUser? _userFromBody(dynamic data) {
    final user = data is Map ? data['user'] : null;
    if (user is! Map) return null;
    final id = user['id'];
    final name = user['name'];
    final email = user['email'];
    if (id is! String || email is! String) return null;
    return AuthUser(id: id, name: (name as String?) ?? '', email: email);
  }

  String _friendlyError(DioException e) {
    final status = e.response?.statusCode;
    final message = e.response?.data is Map
        ? (e.response!.data as Map)['message']
        : null;
    return switch (status) {
      400 || 422 =>
        (message is String && message.isNotEmpty)
            ? message
            : 'Check your details and try again.',
      401 => 'Your session expired. Please log in again.',
      null =>
        'Could not reach the server. Check your connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  Future<AuthUser?> getSession() async {
    await _client.restoreSessionToken();
    try {
      final res = await _client.get<dynamic>('/api/auth/get-session');
      final data = res.data;
      if (data is! Map || data['user'] == null) return null;
      final user = _userFromBody(data);
      if (user == null) {
        await _client.clearSessionToken();
        return null;
      }
      return user;
    } on DioException {
      await _client.clearSessionToken();
      return null;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.post<dynamic>(
        '/api/auth/sign-in/email',
        data: {'email': email, 'password': password},
      );
      await _client.saveSessionToken(res);
      final user = _userFromBody(res.data);
      if (user == null)
        throw const AuthException('We could not start your session.');
      return user;
    } on DioException catch (e) {
      throw AuthException(_friendlyError(e));
    }
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.post<dynamic>(
        '/api/auth/sign-up/email',
        data: {'name': name, 'email': email, 'password': password},
      );
      await _client.saveSessionToken(res);
      final user = _userFromBody(res.data);
      if (user == null)
        throw const AuthException('We could not create your account.');
      return user;
    } on DioException catch (e) {
      throw AuthException(_friendlyError(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.post<dynamic>('/api/auth/sign-out');
    } on DioException {
      // Signing out must still clear the local session even if the
      // network call fails.
    }
    await _client.clearSessionToken();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
