import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

class TripProvider extends ChangeNotifier {
  final TripRepository _repository;

  TripProvider({TripRepository repository = const TripRepository()})
    : _repository = repository;

  final List<TripModel> _trips = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  List<TripModel> get trips => List.unmodifiable(_trips);
  bool get hasOngoingTrip => _trips.any((trip) => trip.status == 'ongoing');
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _repository.getMyTrips(page: _page);
      _trips
        ..clear()
        ..addAll(items);
      _hasMore = items.length >= 20;
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Failed to load trips';
    } catch (_) {
      _error = 'Failed to load trips';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void upsertTrip(TripModel trip) {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index == -1) {
      _trips.insert(0, trip);
    } else {
      _trips[index] = trip;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();

    try {
      final nextPage = _page + 1;
      final items = await _repository.getMyTrips(page: nextPage);
      _page = nextPage;
      _trips.addAll(items);
      _hasMore = items.length >= 20;
      _error = null;
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Failed to load more trips';
    } catch (_) {
      _error = 'Failed to load more trips';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
