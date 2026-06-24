import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/rate_model.dart';
import '../repositories/rate_repository.dart';

class RateProvider extends ChangeNotifier {
  final RateRepository _repository;

  RateProvider({RateRepository repository = const RateRepository()})
      : _repository = repository;

  AreaRateModel? _rate;
  bool _loading = false;
  String? _error;
  bool _showingCached = false;

  AreaRateModel? get rate => _rate;
  bool get loading => _loading;
  String? get error => _error;
  bool get showingCached => _showingCached;

  Future<void> load(String area) async {
    _loading = true;
    _error = null;
    _showingCached = false;
    notifyListeners();

    try {
      _rate = await _repository.getAreaRate(area);
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Failed to load area rates';
      _rate = await _repository.getCachedAreaRate(area);
      _showingCached = _rate != null;
    } catch (_) {
      _error = 'Failed to load area rates';
      _rate = await _repository.getCachedAreaRate(area);
      _showingCached = _rate != null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
