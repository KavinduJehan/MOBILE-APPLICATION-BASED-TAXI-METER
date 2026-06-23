import 'package:dio/dio.dart';

import '../models/driver_model.dart';
import '../services/api_service.dart';

class DriverRepository {
  const DriverRepository();

  Future<List<DriverModel>> getNearbyDrivers({
    String? area,
    String? query,
  }) async {
    final response = await ApiService.getNearbyDrivers(area: area, query: query);
    final list = _readList(response.data);
    final drivers = list.map(DriverModel.fromJson).toList();
    final normalizedQuery = query?.trim().toLowerCase();

    if (normalizedQuery == null || normalizedQuery.isEmpty) {
      return drivers;
    }

    return drivers.where((driver) {
      return driver.name.toLowerCase().contains(normalizedQuery) ||
          driver.vehicleNumber.toLowerCase().contains(normalizedQuery) ||
          driver.vehicleType.toLowerCase().contains(normalizedQuery) ||
          driver.area.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Future<DriverModel> getDriverByQrToken(String qrToken) async {
    final response = await ApiService.getDriverByQR(qrToken);
    return DriverModel.fromJson(_readMap(response.data));
  }

  static List<Map<String, dynamic>> _readList(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map && data['data'] is List) {
      return _readList(data['data']);
    }
    if (data is Map && data['drivers'] is List) {
      return _readList(data['drivers']);
    }
    return const [];
  }

  static Map<String, dynamic> _readMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw DioException(
      requestOptions: RequestOptions(path: '/drivers'),
      error: 'Invalid driver response',
    );
  }
}
