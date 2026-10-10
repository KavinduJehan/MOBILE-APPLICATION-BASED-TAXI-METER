import 'package:flutter_test/flutter_test.dart';
import 'package:offline_trip/offline_trip.dart';

void main() {
  final time = DateTime.utc(2026, 10, 9, 10);
  test(
    'accepted GPS movement accumulates meters and survives checkpoint restore',
    () {
      final engine = DistanceEngine();
      expect(
        engine.addFix(lat: 6.9, lng: 79.8, accuracy: 3, time: time),
        isTrue,
      );
      expect(
        engine.addFix(
          lat: 6.9001,
          lng: 79.8,
          accuracy: 3,
          time: time.add(const Duration(seconds: 5)),
        ),
        isTrue,
      );
      expect(engine.distanceMeters, closeTo(11.119, 0.01));
      final restored = DistanceEngine(
        distanceMeters: engine.distanceMeters,
        lastFix: engine.lastFix,
      );
      restored.addFix(
        lat: 6.9002,
        lng: 79.8,
        accuracy: 3,
        time: time.add(const Duration(seconds: 10)),
      );
      expect(restored.distanceMeters, closeTo(22.239, 0.02));
    },
  );
  test('stationary jitter and bad fixes do not add fare distance', () {
    final engine = DistanceEngine();
    engine.addFix(lat: 6.9, lng: 79.8, accuracy: 8, time: time);
    expect(
      engine.addFix(
        lat: 6.90001,
        lng: 79.8,
        accuracy: 8,
        time: time.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      engine.addFix(
        lat: 6.901,
        lng: 79.8,
        accuracy: 60,
        time: time.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      engine.addFix(
        lat: 6.901,
        lng: 79.8,
        accuracy: 3,
        mocked: true,
        time: time.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
    expect(
      engine.addFix(lat: 6.9, lng: 79.8, accuracy: 3, time: time),
      isFalse,
    );
    expect(
      engine.addFix(lat: double.nan, lng: 79.8, accuracy: 3, time: time),
      isFalse,
    );
    expect(engine.distanceMeters, 0);
  });
  test('impossible GPS jump is rejected and long pause is not billed', () {
    final engine = DistanceEngine();
    engine.addFix(lat: 6.9, lng: 79.8, accuracy: 3, time: time);
    expect(
      engine.addFix(
        lat: 7.9,
        lng: 79.8,
        accuracy: 3,
        time: time.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      engine.addFix(
        lat: 6.91,
        lng: 79.8,
        accuracy: 3,
        time: time.add(const Duration(minutes: 1)),
      ),
      isTrue,
    );
    expect(engine.distanceMeters, 0);
    expect(engine.gapDetected, isTrue);
  });
  test('slow motion is measured after exceeding jitter threshold', () {
    final engine = DistanceEngine();
    engine.addFix(lat: 6.9, lng: 79.8, accuracy: 3, time: time);
    engine.addFix(
      lat: 6.90002,
      lng: 79.8,
      accuracy: 3,
      time: time.add(const Duration(seconds: 1)),
    );
    engine.addFix(
      lat: 6.90006,
      lng: 79.8,
      accuracy: 3,
      time: time.add(const Duration(seconds: 3)),
    );
    expect(engine.distanceMeters, greaterThan(6));
  });
  test('explicit pause excludes movement even during a short tracking gap', () {
    final engine = DistanceEngine();
    engine.addFix(lat: 6.9, lng: 79.8, accuracy: 3, time: time);
    engine.resetAnchor();
    engine.addFix(
      lat: 6.901,
      lng: 79.8,
      accuracy: 3,
      time: time.add(const Duration(seconds: 5)),
    );
    expect(engine.distanceMeters, 0);
    expect(engine.gapDetected, isTrue);
  });
}
