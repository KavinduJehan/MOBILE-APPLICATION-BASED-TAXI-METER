import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small downloadable street map from OSM geometry, drawn locally in both apps.
/// No API key, map tile server, online routing or background downloading.
class RoadMap {
  RoadMap(this.data);
  final Map<String, dynamic> data;
  late final List<Map<String, dynamic>> roads = (data['roads'] as List)
      .map((road) => Map<String, dynamic>.from(road as Map))
      .toList();
  bool contains(LatLng point) =>
      point.latitude >= (data['south'] as num) &&
      point.latitude <= (data['north'] as num) &&
      point.longitude >= (data['west'] as num) &&
      point.longitude <= (data['east'] as num);

  static Future<List<RoadMap>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = <RoadMap>[];
    for (final path in prefs.getStringList('offline_road_maps') ?? []) {
      try {
        maps.add(
          RoadMap(
            Map<String, dynamic>.from(
              jsonDecode(await File(path).readAsString()) as Map,
            ),
          ),
        );
      } catch (_) {
        /* A missing file must not prevent the trip meter from opening. */
      }
    }
    return maps;
  }

  static Future<RoadMap> download(LatLng center) async {
    if (center.latitude.abs() > 80 || center.longitude.abs() > 179) {
      throw const FormatException(
        'Choose an area away from the poles and date line.',
      );
    }
    const deltaLat = 3 / 111.32;
    final deltaLng = deltaLat / math.cos(center.latitude * math.pi / 180);
    final south = center.latitude - deltaLat,
        north = center.latitude + deltaLat;
    final west = center.longitude - deltaLng,
        east = center.longitude + deltaLng;
    final bbox = '$south,$west,$north,$east';
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    try {
      final response = await dio.post(
        'https://overpass-api.de/api/interpreter',
        data: {
          'data': '[out:json][timeout:60];way["highway"]($bbox);out geom;',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final payload = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (payload is! Map ||
          payload['remark'] != null ||
          payload['elements'] is! List) {
        throw const FormatException(
          'The map service could not finish this area. Try again later.',
        );
      }
      final roads = <Map<String, dynamic>>[];
      for (final element in payload['elements'] as List) {
        final way = Map<String, dynamic>.from(element as Map);
        final geometry = way['geometry'] as List?;
        if (geometry == null || geometry.length < 2) continue;
        final tags = Map<String, dynamic>.from(way['tags'] as Map? ?? {});
        roads.add({
          'points': geometry,
          'name': tags['name'] ?? tags['ref'] ?? '',
          'highway': tags['highway'],
        });
      }
      if (roads.isEmpty) {
        throw const FormatException(
          'No mapped streets found here. Choose another area.',
        );
      }
      final map = RoadMap({
        'south': south,
        'west': west,
        'north': north,
        'east': east,
        'centerLat': center.latitude,
        'centerLng': center.longitude,
        'downloadedAt': DateTime.now().toIso8601String(),
        'roads': roads,
      });
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/offline-roads-${DateTime.now().microsecondsSinceEpoch}.json';
      await File(path).writeAsString(jsonEncode(map.data), flush: true);
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList('offline_road_maps') ?? [];
      paths.add(path);
      await prefs.setStringList('offline_road_maps', paths);
      return map;
    } finally {
      dio.close();
    }
  }
}
