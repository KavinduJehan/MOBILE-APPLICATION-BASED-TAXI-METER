import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/driver_profile.dart';
import '../models/trip_record.dart';

class OfflineDatabase {
  OfflineDatabase._();
  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // If running on desktop (Windows/Linux/macOS), initialize FFI
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(dbDirectory.path, 'ridex_driver_offline.db');

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        // Table for storing trips (both offline-created and cached)
        await db.execute('''
          CREATE TABLE local_trips (
            local_id TEXT PRIMARY KEY,
            server_id TEXT,
            customer_name TEXT,
            start_address TEXT,
            end_address TEXT,
            distance_km REAL,
            rate_per_km REAL,
            fare REAL,
            status TEXT,
            date TEXT,
            receipt_number TEXT,
            surge_breakdown TEXT,
            synced_to_cloud INTEGER DEFAULT 0,
            created_at INTEGER
          )
        ''');

        // Table for caching driver profile & current rate
        await db.execute('''
          CREATE TABLE cached_profile (
            id TEXT PRIMARY KEY,
            name TEXT,
            email TEXT,
            phone TEXT,
            license_number TEXT,
            vehicle_number TEXT,
            area TEXT,
            rate_per_km REAL,
            pricing_mode TEXT DEFAULT 'ADMIN',
            is_verified INTEGER,
            updated_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE cached_profile ADD COLUMN pricing_mode TEXT DEFAULT 'ADMIN'");
        }
      },
    );
  }

  /// Inserts a newly completed offline trip
  Future<void> insertOfflineTrip({
    required String localId,
    required String customerName,
    required String startAddress,
    required String endAddress,
    required double distanceKm,
    required double ratePerKm,
    required double fare,
    required String receiptNumber,
    Map<String, dynamic>? surgeBreakdown,
    String status = 'completed',
    DateTime? date,
  }) async {
    final db = await database;
    final now = date ?? DateTime.now();

    await db.insert(
      'local_trips',
      {
        'local_id': localId,
        'server_id': null,
        'customer_name': customerName,
        'start_address': startAddress,
        'end_address': endAddress,
        'distance_km': distanceKm,
        'rate_per_km': ratePerKm,
        'fare': fare,
        'status': status,
        'date': now.toIso8601String(),
        'receipt_number': receiptNumber,
        'surge_breakdown': surgeBreakdown != null ? jsonEncode(surgeBreakdown) : null,
        'synced_to_cloud': 0,
        'created_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates in-progress trip metrics (distance and fare) in local SQLite
  Future<void> updateOfflineTripProgress({
    required String localId,
    required double distanceKm,
    required double fare,
    String? endAddress,
    String status = 'in_progress',
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'distance_km': distanceKm,
      'fare': fare,
      'status': status,
    };
    if (endAddress != null && endAddress.isNotEmpty) {
      values['end_address'] = endAddress;
    }
    await db.update(
      'local_trips',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Caches a server-retrieved trip to local SQLite
  Future<void> cacheServerTrip(TripRecord trip) async {
    final db = await database;
    final dateStr = trip.date?.toIso8601String() ?? DateTime.now().toIso8601String();

    await db.insert(
      'local_trips',
      {
        'local_id': trip.id,
        'server_id': trip.id,
        'customer_name': trip.customerName,
        'start_address': trip.startAddress,
        'end_address': trip.endAddress,
        'distance_km': trip.distanceKm,
        'rate_per_km': trip.ratePerKm,
        'fare': trip.fare,
        'status': trip.status,
        'date': dateStr,
        'receipt_number': trip.receiptNumber,
        'surge_breakdown': trip.surgeBreakdown != null ? jsonEncode(trip.surgeBreakdown) : null,
        'synced_to_cloud': 1,
        'created_at': trip.date?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch cache multiple server trips
  Future<void> cacheServerTrips(List<TripRecord> trips) async {
    final db = await database;
    final batch = db.batch();
    for (final trip in trips) {
      final dateStr = trip.date?.toIso8601String() ?? DateTime.now().toIso8601String();
      batch.insert(
        'local_trips',
        {
          'local_id': trip.id,
          'server_id': trip.id,
          'customer_name': trip.customerName,
          'start_address': trip.startAddress,
          'end_address': trip.endAddress,
          'distance_km': trip.distanceKm,
          'rate_per_km': trip.ratePerKm,
          'fare': trip.fare,
          'status': trip.status,
          'date': dateStr,
          'receipt_number': trip.receiptNumber,
          'surge_breakdown': trip.surgeBreakdown != null ? jsonEncode(trip.surgeBreakdown) : null,
          'synced_to_cloud': 1,
          'created_at': trip.date?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Retrieves all trips from local SQLite (both synced and pending sync)
  Future<List<TripRecord>> getAllTrips() async {
    final db = await database;
    final maps = await db.query('local_trips', orderBy: 'created_at DESC');

    return maps.map((row) {
      Map<String, dynamic>? surge;
      final rawSurge = row['surge_breakdown'] as String?;
      if (rawSurge != null && rawSurge.isNotEmpty) {
        try {
          surge = jsonDecode(rawSurge) as Map<String, dynamic>?;
        } catch (_) {}
      }

      final dateStr = row['date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

      return TripRecord(
        id: (row['server_id'] as String?) ?? (row['local_id'] as String),
        customerName: (row['customer_name'] as String?) ?? 'Customer',
        startAddress: (row['start_address'] as String?) ?? '',
        endAddress: (row['end_address'] as String?) ?? '',
        distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0.0,
        ratePerKm: (row['rate_per_km'] as num?)?.toDouble() ?? 0.0,
        fare: (row['fare'] as num?)?.toDouble() ?? 0.0,
        status: (row['status'] as String?) ?? 'completed',
        date: date,
        receiptNumber: row['receipt_number'] as String?,
        surgeBreakdown: surge,
      );
    }).toList();
  }

  /// Returns un-synced trips ready to be submitted to POST /api/trips/sync
  Future<List<Map<String, dynamic>>> getUnsyncedTrips() async {
    final db = await database;
    final maps = await db.query(
      'local_trips',
      where: 'synced_to_cloud = ?',
      whereArgs: [0],
    );

    return maps.map((row) {
      Map<String, dynamic>? surge;
      final rawSurge = row['surge_breakdown'] as String?;
      if (rawSurge != null && rawSurge.isNotEmpty) {
        try {
          surge = jsonDecode(rawSurge) as Map<String, dynamic>?;
        } catch (_) {}
      }

      return {
        'localId': row['local_id'],
        'customerName': row['customer_name'],
        'startAddress': row['start_address'],
        'endAddress': row['end_address'],
        'distanceKm': row['distance_km'],
        'ratePerKm': row['rate_per_km'],
        'totalFare': row['fare'],
        'status': row['status'],
        'date': row['date'],
        'receiptNumber': row['receipt_number'],
        'surgeBreakdown': surge,
      };
    }).toList();
  }

  /// Returns count of trips pending cloud synchronization
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM local_trips WHERE synced_to_cloud = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Marks synced trips as syncedToCloud = 1 and sets serverId
  Future<void> markTripsSynced(Map<String, dynamic> idMap) async {
    final db = await database;
    final batch = db.batch();

    for (final entry in idMap.entries) {
      final localId = entry.key;
      final serverId = entry.value?.toString();
      batch.update(
        'local_trips',
        {
          'synced_to_cloud': 1,
          'server_id': serverId,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Caches driver profile for offline rate lookup
  Future<void> cacheProfile(DriverProfile profile) async {
    final db = await database;
    await db.insert(
      'cached_profile',
      {
        'id': profile.email.isNotEmpty ? profile.email : 'current_driver',
        'name': profile.name,
        'email': profile.email,
        'phone': profile.phone,
        'license_number': profile.licenseNumber,
        'vehicle_number': profile.vehicleNumber,
        'area': profile.area,
        'rate_per_km': profile.ratePerKm,
        'pricing_mode': profile.pricingMode,
        'is_verified': profile.isVerified ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves cached profile when offline
  Future<DriverProfile?> getCachedProfile() async {
    final db = await database;
    final maps = await db.query('cached_profile', limit: 1);
    if (maps.isEmpty) return null;

    final row = maps.first;
    return DriverProfile(
      name: (row['name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      licenseNumber: (row['license_number'] as String?) ?? '',
      vehicleNumber: (row['vehicle_number'] as String?) ?? '',
      area: (row['area'] as String?) ?? '',
      ratePerKm: (row['rate_per_km'] as num?)?.toDouble() ?? 0.0,
      pricingMode: (row['pricing_mode'] as String?) ?? 'ADMIN',
      isVerified: (row['is_verified'] as int?) == 1,
      qrCode: '',
    );
  }
}
