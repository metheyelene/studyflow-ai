import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// Central HTTP client. Owns the cookie jar and the persisted session
/// token so the app can restore a session across restarts (the token is
/// stored in secure storage and re-attached as a cookie on boot).
class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    // In-memory jar keeps cookies (session cookie) for the process
    // lifetime; the token is also persisted separately for restores.
    dio.interceptors.add(CookieManager(CookieJar()));
    return ApiClient._(dio);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {Object? data}) => _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {Object? data}) => _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);

  /// Persist the session token from a Set-Cookie header (or body token)
  /// so the session survives an app restart.
  Future<void> saveSessionToken(Response<dynamic> response) async {
    final raw = response.headers.value('set-cookie');
    final token = _tokenFromSetCookie(raw) ?? (response.data is Map ? (response.data as Map)['token'] : null);
    if (token is String && token.isNotEmpty) {
      await _secureStorage.write(key: AppConfig.sessionTokenStorageKey, value: token);
    }
  }

  /// Restore the persisted token and attach it as a cookie header.
  Future<String?> restoreSessionToken() async {
    final token = await _secureStorage.read(key: AppConfig.sessionTokenStorageKey);
    if (token != null && token.isNotEmpty) {
      _attachCookie(token);
    }
    return token;
  }

  Future<void> clearSessionToken() async {
    await _secureStorage.delete(key: AppConfig.sessionTokenStorageKey);
    _dio.options.headers.remove('Cookie');
  }

  void _attachCookie(String token) {
    _dio.options.headers['Cookie'] = '${AppConfig.sessionCookieName}=$token';
  }

  String? _tokenFromSetCookie(String? raw) {
    if (raw == null) return null;
    for (final part in raw.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final name = part.substring(0, eq).trim();
      if (name == AppConfig.sessionCookieName) {
        return part.substring(eq + 1).trim();
      }
    }
    return null;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());
