import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Single entry point for all backend HTTP calls.
///
/// Base URL:
///   - Chrome/web        → http://localhost:5000/api
///   - Android emulator  → http://10.0.2.2:5000/api
///   - iOS simulator     → http://localhost:5000/api
///   - Physical device   → replace with your machine's LAN IP, e.g. http://192.168.x.x:5000/api
const String _baseUrl = kIsWeb
    ? 'http://localhost:5000/api'
    : 'http://10.0.2.2:5000/api';

const String _tokenKey = 'auth_token';
const String _customerKey = 'customer_data';
const String _sessionTimestampKey = 'session_timestamp';
const int _sessionExpiryDays = 7; // Tokens expire after 7 days of inactivity

// Token held in memory for the session.
// Also persisted in SharedPreferences for restore across app restarts.
String? _inMemoryToken;

class ApiService {
  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ── Request interceptor — attach JWT if present ──────────────────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _inMemoryToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          // Surface a clean message matching the backend's { message } shape
          final serverMsg = error.response?.data is Map
              ? error.response!.data['message'] as String?
              : null;
          handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: serverMsg ?? error.message,
            ),
          );
        },
      ),
    );

    return dio;
  }

  // ── Token helpers ─────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    _inMemoryToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    // Record the timestamp when token was saved
    await prefs.setInt(_sessionTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clearToken() async {
    _inMemoryToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_customerKey);
    await prefs.remove(_sessionTimestampKey);
  }

  static Future<String?> getToken() async => _inMemoryToken;

  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerKey, _jsonEncode(customer));
  }

  static Future<Map<String, dynamic>?> getCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customerKey);
    if (jsonStr == null) return null;
    return _jsonDecode(jsonStr) as Map<String, dynamic>?;
  }

  static Future<String?> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final timestamp = prefs.getInt(_sessionTimestampKey);

    if (token != null && timestamp != null) {
      // Check if session has expired (older than 7 days)
      final sessionAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      
      if (sessionAge.inDays < _sessionExpiryDays) {
        _inMemoryToken = token;
        return token;
      } else {
        // Session expired, clear it
        await clearToken();
        return null;
      }
    }
    return token;
  }

  // ── Customer Auth ─────────────────────────────────────────────────────────

  /// POST /api/customers/register  — first-time signup
  static Future<Response> customerRegister(String name, String phone) =>
      _dio.post('/customers/register', data: {'name': name, 'phone': phone});

  /// POST /api/customers/request-otp  — send OTP to existing account
  static Future<Response> customerRequestOtp(String phone) =>
      _dio.post('/customers/request-otp', data: {'phone': phone});

  /// POST /api/customers/verify-otp  — validate OTP, returns JWT + customer
  static Future<Response> customerVerifyOtp(String phone, String otp) =>
      _dio.post('/customers/verify-otp', data: {'phone': phone, 'otp': otp});

  // ── Drivers (read-only — customer looks up driver info) ──────────────────

  /// GET /api/drivers/nearby?area=
  static Future<Response> getNearbyDrivers({String? area}) => _dio.get(
    '/drivers/nearby',
    queryParameters: area != null ? {'area': area} : {},
  );

  /// GET /api/drivers/qr/:qrToken
  static Future<Response> getDriverByQR(String qrToken) =>
      _dio.get('/drivers/qr/$qrToken');

  // ── Rates (read-only — customer compares rates) ───────────────────────────

  /// GET /api/rates/area?area=
  static Future<Response> getAreaRates(String area) =>
      _dio.get('/rates/area', queryParameters: {'area': area});

  // ── Ride Requests ─────────────────────────────────────────────────────────

  /// POST /api/ride-requests  — customer JWT required
  static Future<Response> createRideRequest(Map<String, dynamic> body) =>
      _dio.post('/ride-requests', data: body);

  /// GET /api/ride-requests/:id/status  — customer polls
  static Future<Response> getRequestStatus(String requestId) =>
      _dio.get('/ride-requests/$requestId/status');

  // ── JSON serialization helpers ────────────────────────────────────────────

  static String _jsonEncode(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  static Map<String, dynamic>? _jsonDecode(String jsonStr) {
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
