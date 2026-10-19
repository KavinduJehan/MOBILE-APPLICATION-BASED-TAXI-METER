import 'package:flutter/foundation.dart';
import 'package:ridex_driver/offline/offline_trip.dart';

import '../models/trip_record.dart';
import '../services/api_service.dart';

/// Which trip, if any, the driver is currently running. One source of truth so
/// Home, the request screens and the offline screens agree and a second trip
/// can never be started while one is active.
class ActiveTripProvider extends ChangeNotifier {
  TripRecord? _online;
  TripSession? _offline;
  bool _loaded = false;
  bool _refreshing = false;

  TripRecord? get onlineTrip => _online;
  TripSession? get offlineTrip => _offline;
  bool get hasActive => _online != null || _offline != null;

  /// False until the first refresh finishes, so screens do not flash an
  /// "available" state before the real answer is known.
  bool get loaded => _loaded;

  /// Why a new trip cannot start right now, or null if it can.
  String? get blockReason => _online != null
      ? 'Finish your current ride before starting another.'
      : _offline != null
      ? 'Finish your current offline trip before starting another.'
      : null;

  Future<void> refresh(ApiService api, String owner) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // Offline trips live on the phone, so this always works.
      TripSession? offline;
      if (owner.isNotEmpty) {
        final trips = await TripStore.all(owner);
        offline = trips.where((t) => !t.completed).firstOrNull;
      }
      var online = _online;
      try {
        final trips = await api.getMyTrips();
        online = trips.where((t) => t.isOngoing).firstOrNull;
      } catch (_) {
        // Keep the last known online state when the server is unreachable.
      }
      final changed =
          offline?.id != _offline?.id ||
          online?.id != _online?.id ||
          online?.pickedUpAt != _online?.pickedUpAt ||
          online?.arrivedAt != _online?.arrivedAt ||
          !_loaded;
      _offline = offline;
      _online = online;
      _loaded = true;
      if (changed) notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  /// Called right after a trip is accepted so the guard applies immediately,
  /// before the next server refresh.
  void markOnlineStarted(TripRecord trip) {
    _online = trip;
    _loaded = true;
    notifyListeners();
  }

  /// The trip with [tripId] finished or was cancelled; free the driver at once.
  void markOnlineEnded(String tripId) {
    if (_online?.id != tripId) return;
    _online = null;
    notifyListeners();
  }

  void clear() {
    _online = null;
    _offline = null;
    _loaded = false;
    notifyListeners();
  }
}
