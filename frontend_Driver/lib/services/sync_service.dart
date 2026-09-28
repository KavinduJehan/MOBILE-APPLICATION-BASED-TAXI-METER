import 'api_service.dart';
import 'offline_database.dart';

class SyncResult {
  SyncResult({
    required this.syncedCount,
    required this.success,
    this.error,
  });

  final int syncedCount;
  final bool success;
  final String? error;
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final OfflineDatabase _db = OfflineDatabase.instance;

  /// Returns how many offline trips are pending cloud sync
  Future<int> getPendingSyncCount() async {
    return await _db.getUnsyncedCount();
  }

  /// Syncs all unsynced trips recorded locally in SQLite with the server
  Future<SyncResult> syncPendingTrips(ApiService api) async {
    try {
      final unsynced = await _db.getUnsyncedTrips();
      if (unsynced.isEmpty) {
        return SyncResult(syncedCount: 0, success: true);
      }

      final response = await api.syncOfflineTrips(unsynced);
      final idMap = (response['idMap'] as Map?)?.cast<String, dynamic>() ?? {};
      final syncedCount = (response['syncedCount'] as num?)?.toInt() ?? idMap.length;

      if (idMap.isNotEmpty) {
        await _db.markTripsSynced(idMap);
      }

      return SyncResult(syncedCount: syncedCount, success: true);
    } catch (e) {
      return SyncResult(
        syncedCount: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
}
