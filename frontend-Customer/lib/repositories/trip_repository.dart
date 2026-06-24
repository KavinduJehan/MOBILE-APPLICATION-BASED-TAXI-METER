import 'package:dio/dio.dart';

import '../models/receipt_model.dart';
import '../models/trip_model.dart';
import '../services/api_service.dart';

class TripRepository {
  const TripRepository();

  Future<TripModel> createTrip(CreateTripRequest request) async {
    final response = await ApiService.createTrip(request.toJson());
    return TripModel.fromJson(_readMap(response.data));
  }

  Future<TripModel> startTrip(String tripId) async {
    final response = await ApiService.startTrip(tripId);
    return TripModel.fromJson(_readNestedTrip(response.data));
  }

  Future<(TripModel, ReceiptModel?)> endTrip(String tripId) async {
    final response = await ApiService.endTrip(tripId);
    final data = _readMap(response.data);
    final trip = TripModel.fromJson(_readMap(data['trip'] ?? data));
    final receiptData = data['receipt'];
    return (
      trip,
      receiptData == null ? null : ReceiptModel.fromJson(_readMap(receiptData)),
    );
  }

  Future<TripModel> getTripDetails(String tripId) async {
    final response = await ApiService.getTripDetails(tripId);
    return TripModel.fromJson(_readNestedTrip(response.data));
  }

  Future<List<TripModel>> getMyTrips({int page = 1, int limit = 20}) async {
    try {
      final response = await ApiService.getMyTrips(page: page, limit: limit);
      return _readList(response.data).map(TripModel.fromJson).toList();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<ReceiptModel> getReceiptByTripId(String tripId) async {
    final response = await ApiService.getReceiptByTripId(tripId);
    return ReceiptModel.fromJson(_readMap(response.data));
  }

  static Map<String, dynamic> _readNestedTrip(Object? data) {
    final map = _readMap(data);
    return _readMap(map['trip'] ?? map);
  }

  static Map<String, dynamic> _readMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static List<Map<String, dynamic>> _readList(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map && data['data'] is List) return _readList(data['data']);
    if (data is Map && data['trips'] is List) return _readList(data['trips']);
    return const [];
  }
}
