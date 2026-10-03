import 'package:flutter_test/flutter_test.dart';
import 'package:ridex_driver/models/ride_request.dart';
import 'package:ridex_driver/services/ride_alert_service.dart';

void main() {
  group('RideRequest notification payload', () {
    test('parses an FCM data message where every value is a string', () {
      final request = RideRequest.fromJson({
        'type': 'new_request',
        '_id': 'req1',
        'customer': 'cust1',
        'customerName': 'Nimal',
        'pickupAddress': 'Fort',
        'pickupLat': '6.93',
        'pickupLng': '79.85',
        'destAddress': 'Galle Face',
        'destLat': '6.92',
        'destLng': '79.84',
        'estimatedDistanceKm': '2.4',
        'driverRatePerKm': '120',
        'suggestedRatePerKm': '95',
        'status': 'pending',
      });

      expect(request.id, 'req1');
      expect(request.destinationAddress, 'Galle Face');
      expect(request.pickupLatitude, 6.93);
      expect(request.estimatedDistanceKm, 2.4);
      expect(request.suggestedRatePerKm, 95);
    });

    test('treats an empty suggested rate as no offer', () {
      final request = RideRequest.fromJson({'_id': 'r', 'suggestedRatePerKm': ''});
      expect(request.suggestedRatePerKm, isNull);
    });

    test('round-trips through toJson', () {
      final original = RideRequest.fromJson({
        '_id': 'req2',
        'customer': 'cust2',
        'customerName': 'Kamala',
        'pickupAddress': 'Kandy',
        'destAddress': 'Peradeniya',
        'pickupLat': 7.29,
        'pickupLng': 80.63,
        'destLat': 7.26,
        'destLng': 80.59,
        'estimatedDistanceKm': 6.1,
        'driverRatePerKm': 110,
        'createdAt': '2026-10-02T10:00:00.000Z',
      });
      final copy = RideRequest.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.customerId, original.customerId);
      expect(copy.customerName, original.customerName);
      expect(copy.destinationLatitude, original.destinationLatitude);
      expect(copy.driverRatePerKm, original.driverRatePerKm);
      expect(copy.suggestedRatePerKm, isNull);
      expect(copy.createdAt, original.createdAt);
    });
  });

  group('notificationIdFor', () {
    test('is stable and a valid positive Android notification id', () {
      final id = RideAlertService.notificationIdFor('665f1c2e9b1d4a0012ab34cd');
      expect(id, RideAlertService.notificationIdFor('665f1c2e9b1d4a0012ab34cd'));
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('differs between requests', () {
      expect(
        RideAlertService.notificationIdFor('a'),
        isNot(RideAlertService.notificationIdFor('b')),
      );
    });
  });
}
