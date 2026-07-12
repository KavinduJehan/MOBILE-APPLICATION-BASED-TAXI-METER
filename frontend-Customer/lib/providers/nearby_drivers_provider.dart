import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/driver_model.dart';
import '../repositories/driver_repository.dart';

class NearbyDriversProvider extends ChangeNotifier {
  final DriverRepository _repository;

  NearbyDriversProvider({
    DriverRepository repository = const DriverRepository(),
  }) : _repository = repository;

  List<DriverModel> _drivers = const [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String? _area;
  double? _pickupLat;
  double? _pickupLng;

  List<DriverModel> get drivers => _drivers;
  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  String? get area => _area;
  double? get pickupLat => _pickupLat;
  double? get pickupLng => _pickupLng;

  Future<void> load({
    String? area,
    String? query,
    double? pickupLat,
    double? pickupLng,
  }) async {
    _loading = true;
    _error = null;
    _area = area ?? _area;
    _query = query ?? _query;
    _pickupLat = pickupLat;
    _pickupLng = pickupLng;
    notifyListeners();

    try {
      _drivers = await _repository.getNearbyDrivers(
        area: _area,
        query: _query,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
      );
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Failed to load nearby drivers';
    } catch (_) {
      _error = 'Failed to load nearby drivers';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(
    area: _area,
    query: _query,
    pickupLat: _pickupLat,
    pickupLng: _pickupLng,
  );

  Future<void> setSearch(String value) async {
    _query = value;
    await load(
      area: _area,
      query: value,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
    );
  }
}
