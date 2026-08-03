import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String get _baseUrl {
  if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
  return kIsWeb ? 'http://localhost:5000/api' : 'http://172.20.10.3:5000/api';
}

const String _tokenKey = 'auth_token';
const String _refreshTokenKey = 'refresh_token';
const String _customerKey = 'customer_data';
const String _sessionTimestampKey = 'session_timestamp';
const int _sessionExpiryDays = 30;
const Duration _secureStorageTimeout = Duration(seconds: 3);

String? _inMemoryToken;
String? _inMemoryRefreshToken;

class ApiService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Dio _dio = _buildDio();

  static Dio get dio => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _inMemoryToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
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

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    Map<String, dynamic>? customer,
  }) async {
    _inMemoryToken = accessToken;
    _inMemoryRefreshToken = refreshToken;

    final writes = <Future<void>>[
      _writeSecure(_tokenKey, accessToken),
      _writeSecure(
        _sessionTimestampKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      if (refreshToken != null && refreshToken.isNotEmpty)
        _writeSecure(_refreshTokenKey, refreshToken),
      if (customer != null) _writeSecure(_customerKey, jsonEncode(customer)),
    ];

    await Future.wait(writes).timeout(_secureStorageTimeout);
  }

  static Future<void> saveToken(String token) async {
    await saveSession(accessToken: token);
  }

  static Future<void> clearToken() async {
    _inMemoryToken = null;
    _inMemoryRefreshToken = null;
    await Future.wait([
      _deleteSecure(_tokenKey),
      _deleteSecure(_refreshTokenKey),
      _deleteSecure(_customerKey),
      _deleteSecure(_sessionTimestampKey),
    ]).timeout(_secureStorageTimeout);
  }

  static Future<String?> getToken() async {
    _inMemoryToken ??= await _readSecure(_tokenKey);
    return _inMemoryToken;
  }

  static Future<String?> getRefreshToken() async {
    _inMemoryRefreshToken ??= await _readSecure(_refreshTokenKey);
    return _inMemoryRefreshToken;
  }

  static Future<void> saveCustomer(Map<String, dynamic> customer) async {
    await _writeSecure(_customerKey, jsonEncode(customer));
  }

  static Future<Map<String, dynamic>?> getCustomer() async {
    final jsonStr = await _readSecure(_customerKey);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadStoredToken() async {
    final token = await _readSecure(_tokenKey);
    final refreshToken = await _readSecure(_refreshTokenKey);
    final timestampRaw = await _readSecure(_sessionTimestampKey);
    final timestamp = int.tryParse(timestampRaw ?? '');

    if (token == null || timestamp == null) return null;

    final sessionAge = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );

    if (sessionAge.inDays < _sessionExpiryDays) {
      _inMemoryToken = token;
      _inMemoryRefreshToken = refreshToken;
      return token;
    }

    final refreshed = await refreshAccessToken();
    if (refreshed != null) return refreshed;
    await clearToken();
    return null;
  }

  static Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _dio.post(
        '/customers/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final data = _asMap(response.data);
      final token = (data['token'] ?? data['accessToken'])?.toString();
      final newRefreshToken = data['refreshToken']?.toString();
      if (token == null || token.isEmpty) return null;
      await saveSession(
        accessToken: token,
        refreshToken: newRefreshToken ?? refreshToken,
        customer: _asNullableMap(data['customer']),
      );
      return token;
    } on DioException {
      return null;
    }
  }

  static Future<Response> customerRegister({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    return _dio.post(
      '/customers/register',
      data: {
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
      },
    );
  }

  static Future<Response> customerLogin({
    required String identifier,
    required String password,
  }) => _dio.post(
    '/customers/login',
    data: {'identifier': identifier, 'password': password},
  );

  static Future<Response> customerRequestOtp(String phone) =>
      _dio.post('/customers/request-otp', data: {'phone': phone});

  static Future<Response> customerVerifyOtp(String phone, String otp) =>
      _dio.post('/customers/verify-otp', data: {'phone': phone, 'otp': otp});

  static Future<Response> updateCustomerProfile(Map<String, dynamic> body) =>
      _dio.patch('/customers/profile', data: body);

  static Future<Response> getSavedPlaces() =>
      _dio.get('/customers/saved-places');

  static Future<Response> updateSavedPlaces(
    List<Map<String, dynamic>> places,
  ) => _dio.put('/customers/saved-places', data: {'savedPlaces': places});

  static Future<Response> getNearbyDrivers({
    String? area,
    String? query,
    double? pickupLat,
    double? pickupLng,
  }) {
    final queryParameters = <String, dynamic>{};
    if (area != null && area.trim().isNotEmpty) {
      queryParameters['area'] = area.trim();
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParameters['q'] = query.trim();
    }
    if (pickupLat != null) queryParameters['lat'] = pickupLat;
    if (pickupLng != null) queryParameters['lng'] = pickupLng;

    return _dio.get('/drivers/nearby', queryParameters: queryParameters);
  }

  static Future<Response> autocompletePlaces({
    required String input,
    required String sessionToken,
    double? latitude,
    double? longitude,
  }) {
    final queryParameters = <String, dynamic>{
      'input': input,
      'sessionToken': sessionToken,
    };
    if (latitude != null) queryParameters['lat'] = latitude;
    if (longitude != null) queryParameters['lng'] = longitude;
    return _dio.get(
      '/locations/autocomplete',
      queryParameters: queryParameters,
    );
  }

  static Future<Response> getPlaceDetails({
    required String placeId,
    required String sessionToken,
  }) => _dio.get(
    '/locations/details/${Uri.encodeComponent(placeId)}',
    queryParameters: {'sessionToken': sessionToken},
  );

  static Future<Response> reverseGeocode({
    required double latitude,
    required double longitude,
  }) => _dio.get(
    '/locations/reverse',
    queryParameters: {'lat': latitude, 'lng': longitude},
  );
  static Future<Response> getDriverByQR(String qrToken) =>
      _dio.get('/drivers/qr/$qrToken');

  static Future<Response> getAreaRates(String area) =>
      _dio.get('/rates/area', queryParameters: {'area': area});

  static Future<Response> createRideRequest(Map<String, dynamic> body) =>
      _dio.post('/ride-requests', data: body);

  static Future<Response> getRequestStatus(String requestId) =>
      _dio.get('/ride-requests/$requestId/status');

  static Future<Response> createTrip(Map<String, dynamic> body) =>
      _dio.post('/trips', data: body);

  static Future<Response> startTrip(String tripId) =>
      _dio.patch('/trips/$tripId/start');

  static Future<Response> endTrip(String tripId) =>
      _dio.patch('/trips/$tripId/end');

  static Future<Response> getTripDetails(String tripId) =>
      _dio.get('/trips/$tripId');

  static Future<Response> cancelTrip(String tripId) =>
      _dio.patch('/trips/$tripId/cancel');

  static Future<Response> getMyTrips({int page = 1, int limit = 20}) =>
      _dio.get('/trips/my', queryParameters: {'page': page, 'limit': limit});

  static Future<Response> getReceiptByTripId(String tripId) =>
      _dio.get('/receipts/trip/$tripId');

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static Map<String, dynamic>? _asNullableMap(Object? data) {
    if (data == null) return null;
    return _asMap(data);
  }

  static Future<void> _writeSecure(String key, String value) async {
    await _secureStorage
        .write(key: key, value: value)
        .timeout(_secureStorageTimeout);
  }

  static Future<String?> _readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteSecure(String key) async {
    await _secureStorage.delete(key: key).timeout(_secureStorageTimeout);
  }
}
