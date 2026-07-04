import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

typedef AuthExpiredHandler = Future<void> Function();

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthExpiredException extends ApiException {
  const AuthExpiredException()
      : super('Your session expired. Please log in again.', statusCode: 401);
}

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 20);

  static AuthExpiredHandler? onAuthExpired;
  static bool _isHandlingAuthExpired = false;

  // ── Token Management ───────────────────────────────────
  static Future<String?> getToken() async {
    return _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: 'refresh_token');
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  static String messageFromError(Object error) {
    if (error is ApiException) return error.message;
    return 'Connection error. Please try again.';
  }

  // ── AUTH ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return _request(
      'POST',
      '/auth/register',
      requiresAuth: false,
      body: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _request(
      'POST',
      '/auth/login',
      requiresAuth: false,
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) {
    return _request(
      'POST',
      '/auth/forgot-password',
      requiresAuth: false,
      body: {'email': email},
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) {
    return _request(
      'POST',
      '/auth/reset-password',
      requiresAuth: false,
      body: {
        'email': email,
        'code': code,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> getMe() {
    return _request('GET', '/auth/me');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) {
    return _request('PATCH', '/auth/me', body: data);
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    final response = await _request('DELETE', '/auth/me');
    final statusCode = response['statusCode'];
    if (response['status'] == 'error' &&
        (statusCode == 404 || statusCode == 405)) {
      return _request('DELETE', '/users/me');
    }
    return response;
  }

  // ── MEDICATIONS ────────────────────────────────────────
  static Future<Map<String, dynamic>> getMedications() {
    return _request('GET', '/medications');
  }

  static Future<Map<String, dynamic>> createMedication(
    Map<String, dynamic> data,
  ) {
    return _request('POST', '/medications', body: data);
  }

  static Future<Map<String, dynamic>> updateMedication(
    String medicationId,
    Map<String, dynamic> data,
  ) {
    return _request('PATCH', '/medications/$medicationId', body: data);
  }

  static Future<Map<String, dynamic>> deleteMedication(String medicationId) {
    return _request('DELETE', '/medications/$medicationId');
  }

  // ── SCHEDULES ──────────────────────────────────────────
  static Future<Map<String, dynamic>> createSchedule({
    required String medicationId,
    required Map<String, dynamic> data,
  }) {
    return _request(
      'POST',
      '/medications/$medicationId/schedules',
      body: data,
    );
  }

  static Future<Map<String, dynamic>> getMedicationSchedules({
    required String medicationId,
  }) {
    return _request('GET', '/medications/$medicationId/schedules');
  }

  static Future<Map<String, dynamic>> updateSchedule({
    required String scheduleId,
    required Map<String, dynamic> data,
  }) {
    return _request('PATCH', '/schedules/$scheduleId', body: data);
  }

  static Future<Map<String, dynamic>> deleteSchedule(String scheduleId) {
    return _request('DELETE', '/schedules/$scheduleId');
  }

  // ── ADHERENCE ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getToday() {
    return _request('GET', '/adherence/today');
  }

  static Future<Map<String, dynamic>> getStats() {
    return _request('GET', '/adherence/stats');
  }

  static Future<Map<String, dynamic>> logDose(
    Map<String, dynamic> data,
  ) {
    return _request('POST', '/adherence/log', body: data);
  }

  static Future<Map<String, dynamic>> getHistory() {
    return _request(
      'GET',
      '/adherence/history',
      queryParameters: {'limit': '30'},
    );
  }

  // ── AI ASSISTANT ───────────────────────────────────────
  static Future<Map<String, dynamic>> chat({
    required String message,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) {
    return _request(
      'POST',
      '/ai/chat',
      body: {
        'message': message,
        'conversation_history': conversationHistory,
      },
    );
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = _uri(path, queryParameters: queryParameters);
    final headers = await _headers(requiresAuth: requiresAuth);

    try {
      final response = await _send(
        method,
        uri,
        headers: headers,
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 401 && requiresAuth) {
        if (retryOnUnauthorized && await _refreshAccessToken()) {
          return _request(
            method,
            path,
            body: body,
            queryParameters: queryParameters,
            requiresAuth: requiresAuth,
            retryOnUnauthorized: false,
          );
        }

        await _expireSession();
      }

      return _decodeResponse(response);
    } on AuthExpiredException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Request timed out. Please try again.');
    } on FormatException {
      throw const ApiException('The server returned an invalid response.');
    } on http.ClientException {
      throw const ApiException('Could not reach the server.');
    }
  }

  static Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: encodedBody);
      default:
        throw ApiException('Unsupported API method: $method');
    }
  }

  static Future<Map<String, String>> _headers({
    bool requiresAuth = true,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    if (response.body.trim().isEmpty) {
      return {
        'status': isSuccess ? 'success' : 'error',
        'statusCode': response.statusCode,
      };
    }

    final decoded = jsonDecode(response.body);
    final Map<String, dynamic> payload = decoded is Map<String, dynamic>
        ? decoded
        : {
            'status': isSuccess ? 'success' : 'error',
            'data': decoded,
          };

    if (isSuccess) {
      return payload;
    }

    return {
      ...payload,
      'status': 'error',
      'statusCode': response.statusCode,
      'message': payload['message'] ??
          'Request failed with status ${response.statusCode}.',
    };
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final refreshBody = {
      'refreshToken': refreshToken,
      'refresh_token': refreshToken,
    };

    for (final path in ['/auth/refresh', '/auth/refresh-token']) {
      try {
        final response = await http
            .post(
              _uri(path),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(refreshBody),
            )
            .timeout(_timeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final payload = _decodeResponse(response);
        if (payload['status'] != 'success') continue;

        final data = payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload;

        final accessToken =
            data['accessToken']?.toString() ?? data['access_token']?.toString();
        final nextRefreshToken = data['refreshToken']?.toString() ??
            data['refresh_token']?.toString() ??
            refreshToken;

        if (accessToken == null || accessToken.isEmpty) {
          continue;
        }

        await saveTokens(
          accessToken: accessToken,
          refreshToken: nextRefreshToken,
        );
        return true;
      } catch (_) {
        continue;
      }
    }

    return false;
  }

  static Future<void> _expireSession() async {
    await clearTokens();

    if (!_isHandlingAuthExpired) {
      _isHandlingAuthExpired = true;
      try {
        await onAuthExpired?.call();
      } finally {
        _isHandlingAuthExpired = false;
      }
    }

    throw const AuthExpiredException();
  }
}
