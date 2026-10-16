import 'package:flutter_test/flutter_test.dart';
import 'package:ridex_driver/models/ride_request.dart';
import 'package:ridex_driver/services/counter_offer_tracker.dart';

Map<String, dynamic> _json([Map<String, dynamic> overrides = const {}]) => {
  '_id': 'req1',
  'customerName': 'Nimal',
  'estimatedDistanceKm': 10,
  'driverRatePerKm': 80,
  ...overrides,
};

void main() {
  group('RideRequest negotiation state', () {
    test('no suggested rate means no negotiation', () {
      final request = RideRequest.fromJson(_json());
      expect(request.negotiationStatus, 'none');
      expect(request.hasCustomerOffer, isFalse);
      expect(request.awaitingCustomer, isFalse);
    });

    test('a customer offer is waiting for the driver', () {
      final request = RideRequest.fromJson(
        _json({'suggestedRatePerKm': 60, 'negotiationStatus': 'customer_offered'}),
      );
      expect(request.hasCustomerOffer, isTrue);
      expect(request.awaitingCustomer, isFalse);
      expect(request.fareAt(request.suggestedRatePerKm!), 600);
    });

    test('older backends without negotiationStatus still show the offer', () {
      final request = RideRequest.fromJson(_json({'suggestedRatePerKm': 60}));
      expect(request.negotiationStatus, 'customer_offered');
      expect(request.hasCustomerOffer, isTrue);
    });

    test('a sent counter-offer is waiting for the customer', () {
      final request = RideRequest.fromJson(
        _json({
          'suggestedRatePerKm': 60,
          'counterRatePerKm': 70,
          'negotiationStatus': 'driver_countered',
        }),
      );
      expect(request.awaitingCustomer, isTrue);
      expect(request.hasCustomerOffer, isFalse);
      expect(request.counterRatePerKm, 70);
    });

    test('withCounterOffer moves an offer into the waiting state', () {
      final offered = RideRequest.fromJson(
        _json({'suggestedRatePerKm': 60, 'negotiationStatus': 'customer_offered'}),
      );
      final countered = offered.withCounterOffer(72.5);

      expect(countered.awaitingCustomer, isTrue);
      expect(countered.counterRatePerKm, 72.5);
      expect(countered.suggestedRatePerKm, 60);
      expect(countered.id, offered.id);
      // Survives the notification payload round-trip.
      final copy = RideRequest.fromJson(countered.toJson());
      expect(copy.awaitingCustomer, isTrue);
      expect(copy.counterRatePerKm, 72.5);
    });
  });

  group('CounterOfferTracker', () {
    test('skips the request open on the review screen', () {
      final tracker = CounterOfferTracker.instance;
      final a = RideRequest.fromJson(_json({'_id': 'a'}));
      final b = RideRequest.fromJson(_json({'_id': 'b'}));
      tracker
        ..add(a)
        ..add(b);

      tracker.activeRequestId = 'a';
      expect(tracker.waitingElsewhere.map((r) => r.id), ['b']);

      tracker.activeRequestId = null;
      expect(tracker.waitingElsewhere.map((r) => r.id), ['a', 'b']);

      tracker
        ..remove('a')
        ..remove('b');
      expect(tracker.waitingElsewhere, isEmpty);
    });
  });
}
