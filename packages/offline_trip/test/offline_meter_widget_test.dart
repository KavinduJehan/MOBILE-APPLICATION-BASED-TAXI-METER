import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'completed passenger meter displays final fare and bundled navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final trip = TripSession({
        'localId': 'offline-${'a' * 32}',
        'ratePerKm': 80.0,
        'distanceKm': 12.5,
        'status': 'completed',
        'startTime': '2026-01-01T10:00:00Z',
        'endTime': '2026-01-01T10:10:00Z',
        'driverName': 'Test Driver',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineMeterScreen(
            trip: trip,
            owner: 'customer',
            driverMode: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Trip completed'), findsOneWidget);
      expect(find.text('12.50 km'), findsOneWidget);
      expect(find.textContaining('Rs. 1000.00'), findsOneWidget);
      expect(find.text('Offline navigation'), findsOneWidget);
      expect(find.textContaining('No map download needed'), findsOneWidget);
      expect(find.text('End offline trip'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
