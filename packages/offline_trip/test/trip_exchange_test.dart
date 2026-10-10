import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'pending QR offers survive restart and stay separate from trip history',
    () async {
      SharedPreferences.setMockInitialValues({});
      await TripStore.saveOffer('customer-a', {'localId': 'offer-a'});
      expect(
        (await TripStore.pendingOffer('customer-a'))!['localId'],
        'offer-a',
      );
      expect(await TripStore.pendingOffer('customer-b'), isNull);
      expect(await TripStore.all('customer-a'), isEmpty);
      await TripStore.clearOffer('customer-a');
      expect(await TripStore.pendingOffer('customer-a'), isNull);
    },
  );
  TripSession trip() => TripSession({
    'localId': 'offline-${'a' * 32}',
    'driverToken': 'driver-token',
    'driverId': 'driver-id',
    'ratePerKm': 100.0,
    'distanceKm': 1.2345,
    'status': 'completed',
    'startTime': '2026-01-01T10:00:00Z',
    'endTime': '2026-01-01T10:10:00Z',
  });
  test('acceptance and receipt carry the same identity and agreed fare', () {
    final session = trip();
    final receipt = Map<String, dynamic>.from(
      jsonDecode(session.qr('TRIP_RECEIPT')) as Map,
    );
    session.validateExchange(receipt, 'TRIP_RECEIPT');
    expect(receipt['totalFare'], 123.45);
    session.validateExchange(
      Map<String, dynamic>.from(jsonDecode(session.qr('TRIP_ACCEPTED')) as Map),
      'TRIP_ACCEPTED',
    );
  });
  test('wrong trip, driver, rate and forged receipt totals are rejected', () {
    final session = trip();
    final receipt = Map<String, dynamic>.from(
      jsonDecode(session.qr('TRIP_RECEIPT')) as Map,
    );
    for (final change in [
      {'localId': 'other'},
      {'driverToken': 'other'},
      {'ratePerKm': 110},
      {'totalFare': 1},
      {'distanceKm': -1},
      {'endTime': '2025-01-01T00:00:00Z'},
    ]) {
      expect(
        () => session.validateExchange({...receipt, ...change}, 'TRIP_RECEIPT'),
        throwsFormatException,
      );
    }
  });
  test('acceptance confirms the chosen destination and navigation profile', () {
    final session = trip();
    session.data['destination'] = {
      'latitude': 6.9271,
      'longitude': 79.8612,
      'name': 'Colombo',
    };
    session.data['navigationProfile'] = 'tuk';
    final qr = Map<String, dynamic>.from(
      jsonDecode(session.qr('TRIP_ACCEPTED')) as Map,
    );
    session.validateExchange(qr, 'TRIP_ACCEPTED');
    expect(
      () => session.validateExchange({
        ...qr,
        'navigationProfile': 'car',
      }, 'TRIP_ACCEPTED'),
      throwsFormatException,
    );
    expect(
      () => session.validateExchange({
        ...qr,
        'destination': {
          'latitude': 7.2906,
          'longitude': 80.6337,
          'name': 'Kandy',
        },
      }, 'TRIP_ACCEPTED'),
      throwsFormatException,
    );
  });
  test(
    'persistent trips are isolated per account and restore completion',
    () async {
      SharedPreferences.setMockInitialValues({});
      await TripStore.save('driver-a', trip());
      expect(await TripStore.all('driver-b'), isEmpty);
      final restored = await TripStore.find('driver-a', trip().id);
      expect(restored!.completed, isTrue);
      expect(restored.distanceKm, 1.2345);
    },
  );
}
