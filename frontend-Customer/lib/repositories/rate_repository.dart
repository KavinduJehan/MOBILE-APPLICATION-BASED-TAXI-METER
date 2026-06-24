import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rate_model.dart';
import '../services/api_service.dart';

class RateRepository {
  static const _cachePrefix = 'cached_area_rate_';

  const RateRepository();

  Future<AreaRateModel> getAreaRate(String area) async {
    try {
      final response = await ApiService.getAreaRates(area);
      final data = _readMap(response.data);
      final rate = AreaRateModel.fromJson({
        ...data,
        'area': data['area'] ?? area,
        'baseFare': data['baseFare'] ?? 0,
        'perKmCharge': data['perKmCharge'] ?? data['averageRate'],
        'waitingCharge': data['waitingCharge'] ?? 0,
        'surgeMultiplier': data['surgeMultiplier'] ?? 1,
        'lastUpdatedAt': data['lastUpdatedAt'] ??
            data['updatedAt'] ??
            DateTime.now().toIso8601String(),
      });
      await _cacheRate(rate);
      return rate;
    } catch (_) {
      final cached = await getCachedAreaRate(area);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<AreaRateModel?> getCachedAreaRate(String area) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachePrefix${area.toLowerCase()}');
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return AreaRateModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> _cacheRate(AreaRateModel rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cachePrefix${rate.areaName.toLowerCase()}',
      jsonEncode(rate.toJson()),
    );
  }

  static Map<String, dynamic> _readMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
