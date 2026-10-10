import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'trip_session.dart';

/// Each trip has its own key, scoped to the logged-in account. No list-write races.
class TripStore {
  static Future<void> saveOffer(
    String owner,
    Map<String, dynamic> offer,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      'offline_offer_v1_$owner',
      jsonEncode(offer),
    );
  }

  static Future<Map<String, dynamic>?> pendingOffer(String owner) async {
    final source = (await SharedPreferences.getInstance()).getString(
      'offline_offer_v1_$owner',
    );
    return source == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(source) as Map);
  }

  static Future<void> clearOffer(String owner) async {
    await (await SharedPreferences.getInstance()).remove(
      'offline_offer_v1_$owner',
    );
  }

  static String _prefix(String owner) => 'offline_trip_v1_${owner}_';
  static Future<void> save(String owner, TripSession trip) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      '${_prefix(owner)}${trip.id}',
      jsonEncode(trip.data),
    )) {
      throw StateError('Unable to save trip on this device.');
    }
  }

  static Future<List<TripSession>> all(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = <TripSession>[];
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_prefix(owner)),
    )) {
      final source = prefs.getString(key);
      if (source != null)
        trips.add(
          TripSession(Map<String, dynamic>.from(jsonDecode(source) as Map)),
        );
    }
    trips.sort((a, b) => b.startTime.compareTo(a.startTime));
    return trips;
  }

  static Future<TripSession?> find(String owner, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString('${_prefix(owner)}$id');
    return source == null
        ? null
        : TripSession(Map<String, dynamic>.from(jsonDecode(source) as Map));
  }
}
