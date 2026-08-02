import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

class TripProvider extends ChangeNotifier {
  final TripRepository _repository;

  TripProvider({TripRepository repository = const TripRepository()})
    : _repository = repository {
    _pendingRestore = _restorePendingSearch();
  }

  final List<TripModel> _trips = [];
  late final Future<void> _pendingRestore;
  PendingRideSearch? _pendingSearch;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  List<TripModel> get trips => List.unmodifiable(_trips);
  PendingRideSearch? get pendingSearch => _pendingSearch;
  bool get hasOngoingTrip =>
      _pendingSearch != null ||
      _trips.any(
        (trip) =>
            trip.status.toLowerCase() == 'ongoing' ||
            trip.status.toLowerCase() == 'pending',
      );
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  static const _pendingSearchKey = 'customer_pending_driver_search';

  Future<void> _restorePendingSearch() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_pendingSearchKey);
    if (source == null || source.isEmpty) return;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return;
      _pendingSearch = PendingRideSearch.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      notifyListeners();
    } catch (_) {
      await prefs.remove(_pendingSearchKey);
    }
  }

  Future<void> startDriverSearch({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
  }) async {
    await _pendingRestore;
    _pendingSearch = PendingRideSearch(
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destinationAddress: destinationAddress,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      createdAt: DateTime.now(),
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingSearchKey,
      jsonEncode(_pendingSearch!.toJson()),
    );
  }

  Future<void> clearPendingSearch() async {
    await _pendingRestore;
    if (_pendingSearch == null) return;
    _pendingSearch = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSearchKey);
  }

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

  Future<bool> cancelTrip(String tripId) async {
    try {
      final trip = await _repository.cancelTrip(tripId);
      upsertTrip(trip);
      _error = null;
      return true;
    } on DioException catch (error) {
      _error = error.error?.toString() ?? 'Failed to cancel trip';
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to cancel trip';
      notifyListeners();
      return false;
    }
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

class PendingRideSearch {
  const PendingRideSearch({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.createdAt,
  });

  factory PendingRideSearch.fromJson(Map<String, dynamic> json) {
    return PendingRideSearch(
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      pickupLat: _readDouble(json['pickupLat']),
      pickupLng: _readDouble(json['pickupLng']),
      destinationAddress: (json['destinationAddress'] ?? '').toString(),
      destinationLat: _readDouble(json['destinationLat']),
      destinationLng: _readDouble(json['destinationLng']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'pickupAddress': pickupAddress,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'destinationAddress': destinationAddress,
    'destinationLat': destinationLat,
    'destinationLng': destinationLng,
    'createdAt': createdAt.toIso8601String(),
  };

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
