import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ── Token Management ───────────────────────────────────
  static Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
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

  // ── Headers ────────────────────────────────────────────
  static Future<Map<String, String>> _headers({
    bool requiresAuth = true,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── AUTH ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ── MEDICATIONS ────────────────────────────────────────
  static Future<Map<String, dynamic>> getMedications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/medications'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createMedication(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/medications'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ── SCHEDULES ──────────────────────────────────────────
  static Future<Map<String, dynamic>> createSchedule({
    required String medicationId,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/medications/$medicationId/schedules'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ── ADHERENCE ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getToday() async {
    final response = await http.get(
      Uri.parse('$baseUrl/adherence/today'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/adherence/stats'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> logDose(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/adherence/log'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }
  static Future<Map<String, dynamic>> getHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/adherence/history?limit=30'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);

  }
  // ── AI ASSISTANT ───────────────────────────────────────
  static Future<Map<String, dynamic>> chat({
    required String message,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: await _headers(),
      body: jsonEncode({
        'message': message,
        'conversation_history': conversationHistory,
      }),
    );
    return jsonDecode(response.body);
  }
}