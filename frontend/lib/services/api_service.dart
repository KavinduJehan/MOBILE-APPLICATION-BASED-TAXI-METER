import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single entry point for all backend HTTP calls.
///
/// Base URL:
///   - Android emulator  → http://10.0.2.2:5000/api
///   - iOS simulator     → http://localhost:5000/api
///   - Physical device   → replace with your machine's LAN IP, e.g. http://192.168.x.x:5000/api
const String _baseUrl = 'http://10.0.2.2:5000/api';

const _storage = FlutterSecureStorage();
const _tokenKey = 'adminToken';

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
          final token = await _storage.read(key: _tokenKey);
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

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// POST /api/auth/register
  static Future<Response> register(Map<String, dynamic> body) =>
      _dio.post('/auth/register', data: body);

  /// POST /api/auth/login  — email + password
  static Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  /// POST /api/auth/phone-login  — Firebase ID token after OTP
  static Future<Response> phoneLogin(
    String idToken, {
    String? name,
    String? licenseNumber,
    String? vehicleNumber,
    String? area,
  }) =>
      _dio.post('/auth/phone-login', data: {
        'idToken': idToken,
        if (name != null) 'name': name,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
        if (area != null) 'area': area,
      });

  // ── Driver ────────────────────────────────────────────────────────────────

  /// GET /api/drivers/profile
  static Future<Response> getProfile() => _dio.get('/drivers/profile');

  /// POST /api/drivers/generate-qr
  static Future<Response> generateQR() => _dio.post('/drivers/generate-qr');

  /// PATCH /api/drivers/location
  static Future<Response> updateLocation(double lat, double lng) =>
      _dio.patch('/drivers/location', data: {'lat': lat, 'lng': lng});

  /// GET /api/drivers/nearby?area=
  static Future<Response> getNearbyDrivers({String? area}) =>
      _dio.get('/drivers/nearby', queryParameters: if (area != null) {'area': area} else {});

  /// GET /api/drivers/qr/:qrToken
  static Future<Response> getDriverByQR(String qrToken) =>
      _dio.get('/drivers/qr/$qrToken');

  // ── Rates ─────────────────────────────────────────────────────────────────

  /// PATCH /api/rates
  static Future<Response> updateRate(double ratePerKm) =>
      _dio.patch('/rates', data: {'ratePerKm': ratePerKm});

  /// GET /api/rates?area=
  static Future<Response> getAreaRates(String area) =>
      _dio.get('/rates', queryParameters: {'area': area});

  // ── Trips ─────────────────────────────────────────────────────────────────

  /// POST /api/trips
  static Future<Response> createTrip(Map<String, dynamic> body) =>
      _dio.post('/trips', data: body);

  /// PATCH /api/trips/:id/end
  static Future<Response> endTrip(String tripId) =>
      _dio.patch('/trips/$tripId/end');

  /// GET /api/trips/my
  static Future<Response> getMyTrips() => _dio.get('/trips/my');

  /// GET /api/trips/income
  static Future<Response> getIncome() => _dio.get('/trips/income');

  // ── Ride Requests ─────────────────────────────────────────────────────────

  /// POST /api/ride-requests  (no auth — customer)
  static Future<Response> createRideRequest(Map<String, dynamic> body) =>
      _dio.post('/ride-requests', data: body);

  /// GET /api/ride-requests/incoming  (driver)
  static Future<Response> getIncomingRequests() =>
      _dio.get('/ride-requests/incoming');

  /// GET /api/ride-requests/:id/status  (customer polls)
  static Future<Response> getRequestStatus(String requestId) =>
      _dio.get('/ride-requests/$requestId/status');

  /// PATCH /api/ride-requests/:id/respond  (driver)
  static Future<Response> respondToRequest(String requestId, bool accept,
          {double? agreedRate}) =>
      _dio.patch('/ride-requests/$requestId/respond', data: {
        'accept': accept,
        if (agreedRate != null) 'agreedRatePerKm': agreedRate,
      });
}
