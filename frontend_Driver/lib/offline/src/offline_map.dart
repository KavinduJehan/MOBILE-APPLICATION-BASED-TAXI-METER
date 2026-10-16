import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'navigation_screen.dart';

/// Reads raster MBTiles directly; never requests tiles from the network.
class OfflineMapArchive {
  OfflineMapArchive(this.db, this.metadata);
  final Database db;
  final Map<String, String> metadata;
  int get minZoom => int.tryParse(metadata['minzoom'] ?? '') ?? 0;
  int get maxZoom => int.tryParse(metadata['maxzoom'] ?? '') ?? 18;
  String get attribution =>
      metadata['attribution'] ?? 'Map attribution not supplied';

  static Future<OfflineMapArchive> open(String path) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final db = await openDatabase(path, readOnly: true, singleInstance: false);
    try {
      final rows = await db.query('metadata');
      final meta = {
        for (final row in rows) row['name'].toString(): row['value'].toString(),
      };
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(meta['format'])) {
        throw const FormatException(
          'Use a raster PNG/JPEG/WebP MBTiles map. Vector PBF maps are not supported.',
        );
      }
      final sample = await db.query('tiles', columns: ['tile_data'], limit: 1);
      if (sample.isEmpty) throw const FormatException('This map has no tiles.');
      final codec = await ui.instantiateImageCodec(
        sample.first['tile_data'] as Uint8List,
      );
      codec.dispose();
      return OfflineMapArchive(db, meta);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<Uint8List?> tile(int x, int y, int z) async {
    // MBTiles uses TMS rows; flutter_map uses XYZ.
    final rows = await db.query(
      'tiles',
      columns: ['tile_data'],
      where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
      whereArgs: [z, x, (1 << z) - 1 - y],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['tile_data'] as Uint8List;
  }

  static Future<String?> savedPath() async =>
      (await SharedPreferences.getInstance()).getString(
        'offline_raster_map_path',
      );

  static Future<String?> importMap() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Offline map import is available in the mobile and desktop apps.',
      );
    }
    // Some Android document providers do not recognise the .mbtiles extension.
    final file = await openFile();
    if (file == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/offline-map-${DateTime.now().microsecondsSinceEpoch}.mbtiles';
    await file.saveTo(path);
    try {
      final archive = await open(path);
      await archive.db.close();
      await (await SharedPreferences.getInstance()).setString(
        'offline_raster_map_path',
        path,
      );
      return path;
    } catch (_) {
      await File(path).delete();
      rethrow;
    }
  }
}

/// Entry point shared by the offline hubs and trip meters.
class OfflineTripMap extends StatelessWidget {
  const OfflineTripMap({
    super.key,
    required this.points,
    this.destination,
    this.profile = 'car',
  });
  final List<LatLng> points;
  final OfflineDestination? destination;
  final String profile;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 270,
        child: BundledRoadMap(
          initialCenter: points.isNotEmpty
              ? points.last
              : destination?.point ?? const LatLng(7.8, 80.7),
          initialZoom: points.isNotEmpty || destination != null ? 14 : 7,
          trail: points,
          position: points.isEmpty ? null : points.last,
          destination: destination?.point,
        ),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfflineNavigationScreen(
              initialPosition: points.isEmpty ? null : points.last,
              destination: destination,
              profile: profile,
            ),
          ),
        ),
        icon: const Icon(Icons.navigation),
        label: const Text('Offline navigation'),
      ),
    ],
  );
}
