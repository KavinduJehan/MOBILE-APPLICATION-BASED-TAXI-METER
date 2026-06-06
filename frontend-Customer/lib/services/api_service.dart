import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

// Token held in memory for the session.
// Replace with flutter_secure_storage when deploying to production.
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

  static Future<void> saveToken(String token) async => _inMemoryToken = token;

  static Future<void> clearToken() async => _inMemoryToken = null;

  static Future<String?> getToken() async => _inMemoryToken;

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

  /// GET /api/rates?area=
  static Future<Response> getAreaRates(String area) =>
      _dio.get('/rates', queryParameters: {'area': area});

  // ── Ride Requests ─────────────────────────────────────────────────────────

  /// POST /api/ride-requests  — customer JWT required
  static Future<Response> createRideRequest(Map<String, dynamic> body) =>
      _dio.post('/ride-requests', data: body);

  /// GET /api/ride-requests/:id/status  — customer polls
  static Future<Response> getRequestStatus(String requestId) =>
      _dio.get('/ride-requests/$requestId/status');
}
