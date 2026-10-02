import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/api_exception.dart';
import '../models/auth_result.dart';
import '../models/driver_profile.dart';
import '../models/income_summary.dart';
import '../models/qr_result.dart';
import '../models/ride_request.dart';
import '../models/trip_completion.dart';
import '../models/trip_record.dart';
import 'session_store.dart';

class ApiService {
  ApiService({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  final Dio _dio;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login',
      auth: false,
      data: {'email': email, 'password': password},
    );
    final data = _asMap(response.data);
    final token = _readString(data, ['token', 'jwt', 'accessToken']);
    if (token.isEmpty) {
      throw ApiException('Login succeeded but no token was returned.');
    }
    final profileMap = _readMap(data, ['driver', 'user', 'profile']);
    return AuthResult(
      token: token,
      profile: profileMap == null ? null : DriverProfile.fromJson(profileMap),
      message: _readString(data, ['message']),
    );
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _request(
      'POST',
      '/auth/forgot-password',
      auth: false,
      data: {'email': email},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _request(
      'POST',
      '/auth/reset-password',
      auth: false,
      data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
    );
    return _asMap(response.data);
  }

  Future<String> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String licenseNumber,
    required String vehicleNumber,
    String area = '',
  }) async {
    final response = await _request(
      'POST',
      '/auth/register',
      auth: false,
      data: {
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'licenseNumber': licenseNumber,
        'vehicleNumber': vehicleNumber,
        'area': area,
        'role': 'driver',
      },
    );
    final data = _asMap(response.data);
    return _readString(data, ['message'], fallback: 'Account created.');
  }

  Future<DriverProfile> getProfile() async {
    final response = await _request('GET', '/drivers/profile');
    return DriverProfile.fromJson(_asMap(response.data));
  }

  Future<QrResult> generateQr() async {
    final response = await _request('POST', '/drivers/generate-qr');
    final data = _asMap(response.data);
    return QrResult(
      qrCode: _readString(data, ['qrCode', 'qr_code', 'image']),
      token: _readString(data, ['token'], fallback: ''),
    );
  }

  Future<void> updateRate(double ratePerKm) async {
    await _request('PATCH', '/rates/my-rate', data: {'ratePerKm': ratePerKm});
  }

  /// Update editable driver profile fields.
  Future<DriverProfile> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String vehicleNumber,
    String area = '',
  }) async {
    final response = await _request(
      'PATCH',
      '/drivers/profile',
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'vehicleNumber': vehicleNumber,
        'area': area,
      },
    );
    return DriverProfile.fromJson(_asMap(response.data));
  }

  Future<double> getAreaRate(String area) async {
    final response = await _request(
      'GET',
      '/rates/area',
      auth: false,
      queryParameters: {'area': area},
    );
    final data = _asMap(response.data);
    return _readDouble(data, ['ratePerKm', 'averageRate', 'rate', 'value']);
  }

  /// Fetches the real-time auto-calculated rate with surge breakdown.
  /// Returns a map containing: effectiveRate, baseRate, multiplier, breakdown.
  Future<Map<String, dynamic>> getAutoRate({String? area, double? lat, double? lng}) async {
    final query = <String, dynamic>{};
    if (lat != null && lng != null) {
      query['lat'] = lat;
      query['lng'] = lng;
    } else if (area != null && area.isNotEmpty) {
      query['area'] = area;
    }
    final response = await _request(
      'GET',
      '/rates/auto',
      auth: false,
      queryParameters: query,
    );
    return _asMap(response.data);
  }

  /// Fetch the receipt for a completed trip.
  Future<Map<String, dynamic>> getReceiptForTrip(String tripId) async {
    final response = await _request('GET', '/receipts/trip/$tripId');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getPublicConfig() async {
    final response = await _request('GET', '/config/public', auth: false);
    return _asMap(response.data);
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    await _request(
      'PATCH',
      '/drivers/location',
      data: {'lat': lat, 'lng': lng},
    );
  }

  Future<Map<String, dynamic>> getDrivingRoute({
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final response = await _request(
      'POST',
      '/locations/route',
      data: {
        'pickupLat': pickupLatitude,
        'pickupLng': pickupLongitude,
        'destinationLat': destinationLatitude,
        'destinationLng': destinationLongitude,
      },
    );
    return _asMap(response.data);
  }

  Future<List<RideRequest>> getIncomingRequests() async {
    final response = await _request('GET', '/ride-requests/incoming');
    final list = _extractList(response.data, ['requests', 'data', 'items']);
    return list.map(RideRequest.fromJson).toList();
  }

  Future<Map<String, dynamic>> respondToRequest({
    required String requestId,
    required String action,
    double? agreedRatePerKm,
  }) async {
    final data = <String, dynamic>{'action': action};
    if (agreedRatePerKm != null) {
      data['agreedRatePerKm'] = agreedRatePerKm;
    }
    final response = await _request(
      'PATCH',
      '/ride-requests/$requestId/respond',
      data: data,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createTrip({required String requestId}) async {
    final response = await _request(
      'POST',
      '/trips',
      data: {'requestId': requestId},
    );
    return _asMap(response.data);
  }

  Future<TripRecord> startTrip(String tripId) async {
    final response = await _request('PATCH', '/trips/$tripId/start');
    final data = _asMap(response.data);
    final tripMap = _readMap(data, ['trip']) ?? data;
    return TripRecord.fromJson(tripMap);
  }

  Future<TripCompletionResult> endTrip(String tripId) async {
    final response = await _request('PATCH', '/trips/$tripId/end');
    final data = _asMap(response.data);
    final tripMap = _readMap(data, ['trip']) ?? data;
    return TripCompletionResult(
      trip: TripRecord.fromJson(tripMap),
      receiptNumber: _readString(data, [
        'receipt',
        'receiptNumber',
        'receiptId',
      ], fallback: ''),
    );
  }

  Future<List<TripRecord>> getMyTrips() async {
    final response = await _request('GET', '/trips/my');
    final list = _extractList(response.data, ['trips', 'data', 'items']);
    return list.map(TripRecord.fromJson).toList();
  }

  Future<IncomeSummary> getIncomeSummary() async {
    final response = await _request('GET', '/trips/income');
    return IncomeSummary.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> syncOfflineTrips(List<Map<String, dynamic>> trips) async {
    final response = await _request(
      'POST',
      '/trips/sync',
      data: {'trips': trips},
    );
    return _asMap(response.data);
  }

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    bool auth = true,
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    final options = Options(method: method);
    if (auth) {
      final token = await SessionStore.readToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Please sign in again.');
      }
      options.headers = {'Authorization': 'Bearer $token'};
    }

    try {
      return await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw ApiException(_extractMessage(error));
    } catch (error) {
      throw ApiException(error.toString());
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      if (value != null) {
        return value.toString();
      }
    }
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> data,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  Map<String, dynamic>? _readMap(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  // Extracts a list of maps from various response shapes:
  // - top-level JSON array: [ {...}, {...} ]
  // - wrapped object: { "trips": [...] } or { "requests": [...] }
  // - nested under common keys provided in `keys`
  List<Map<String, dynamic>> _extractList(dynamic data, List<String> keys) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // fallback: if any value is a List, return the first one
      for (final entry in data.entries) {
        if (entry.value is List) {
          return (entry.value as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // if it's a non-empty map, return it as a single-item list
      if (data.isNotEmpty) return [Map<String, dynamic>.from(data)];
      return const [];
    }

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      return _extractList(m, keys);
    }

    return const [];
  }

  String _extractMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return error.message ?? 'Network request failed.';
  }
}
