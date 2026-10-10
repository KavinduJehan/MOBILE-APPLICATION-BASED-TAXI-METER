import 'dart:async';

import 'api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'offline_database.dart';
import 'session_store.dart';
import 'package:offline_trip/offline_trip.dart';

class SyncResult {
  SyncResult({required this.syncedCount, required this.success, this.error});

  final int syncedCount;
  final bool success;
  final String? error;
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final OfflineDatabase _db = OfflineDatabase.instance;
  Future<SyncResult>? _inFlight;

  /// Returns how many offline trips are pending cloud sync
  Future<int> getPendingSyncCount() async {
    return await _db.getUnsyncedCount();
  }

  /// Syncs all unsynced trips recorded locally in SQLite with the server
  Future<SyncResult> syncPendingTrips(ApiService api) {
    return _inFlight ??= _sync(api).whenComplete(() => _inFlight = null);
  }

  Future<SyncResult> _sync(ApiService api) async {
    try {
      final profile = await SessionStore.readProfile();
      if (profile == null || profile.id.isEmpty) {
        return SyncResult(
          syncedCount: 0,
          success: false,
          error: 'Refresh your driver profile to sync offline trips.',
        );
      }
      final owner = profile.id;
      // Recover completion if the app was closed between journal save and queueing.
      final localTrips = await TripStore.all(owner);
      for (final trip in localTrips.where(
        (trip) => trip.completed && trip.data['serverId'] == null,
      )) {
        await _db.queueOfflineSnapshot(owner, trip.data);
      }
      final unsynced = await _db.getUnsyncedTrips(owner: owner);
      if (unsynced.isEmpty) {
        return SyncResult(syncedCount: 0, success: true);
      }

      var syncedCount = 0;
      for (var offset = 0; offset < unsynced.length; offset += 100) {
        final end = (offset + 100 < unsynced.length)
            ? offset + 100
            : unsynced.length;
        final response = await api.syncOfflineHandshakeTrips(
          unsynced.sublist(offset, end),
        );
        final idMap =
            (response['idMap'] as Map?)?.cast<String, dynamic>() ?? {};
        syncedCount += idMap.length;
        if (idMap.isNotEmpty) {
          await _db.markTripsSynced(idMap);
          for (final entry in idMap.entries) {
            final trip = await TripStore.find(owner, entry.key);
            if (trip != null) {
              trip.data['serverId'] = entry.value;
              await TripStore.save(owner, trip);
            }
          }
        }
      }

      return SyncResult(syncedCount: syncedCount, success: true);
    } catch (e) {
      return SyncResult(syncedCount: 0, success: false, error: e.toString());
    }
  }
}

/// Retries pending completed trips when connectivity or app foreground state changes.
class OfflineSyncCoordinator with WidgetsBindingObserver {
  OfflineSyncCoordinator(this._api);

  final ApiService _api;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _started = false;
  bool _syncing = false;
  bool _foreground = true;
  Timer? _retryTimer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncNow();
      }
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (!_started || !_foreground || _syncing) return;
    _syncing = true;
    try {
      await SyncService.instance.syncPendingTrips(_api);
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      syncNow();
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
