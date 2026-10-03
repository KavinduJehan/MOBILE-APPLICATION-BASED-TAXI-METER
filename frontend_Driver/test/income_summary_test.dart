import 'package:flutter_test/flutter_test.dart';
import 'package:ridex_driver/models/income_summary.dart';

void main() {
  test('reads backend daily earnings and completed trip counts', () {
    final summary = IncomeSummary.fromJson({
      'totalEarnings': 1200,
      'totalTrips': 3,
      'completedTrips': 3,
      'byDay': {'2026-10-02': 800, '2026-09-01': 400},
      'tripsByDay': {'2026-10-02': 2, '2026-09-01': 1},
    });
    final days = summary.daysForPeriod(7, DateTime(2026, 10, 2));
    expect(days.length, 7);
    expect(days.first.label, '2026-09-26');
    expect(days.last.amount, 800);
    expect(days.fold<double>(0, (sum, day) => sum + day.amount), 800);
    expect(days.fold<int>(0, (sum, day) => sum + day.trips!), 2);
    expect(days.first.amount, 0);
    expect(days.first.trips, 0);
    expect(summary.totalEarnings, 1200);
  });

  test('uses calendar boundaries and excludes old and future fares', () {
    final summary = IncomeSummary.fromJson({
      'byDay': {'2026-09-03': 50, '2026-09-02': 70, '2026-10-03': 100},
    });
    final days = summary.daysForPeriod(30, DateTime(2026, 10, 2));
    expect(days.first.label, '2026-09-03');
    expect(days.last.label, '2026-10-02');
    expect(days.fold<double>(0, (sum, day) => sum + day.amount), 50);
    expect(days.first.trips, isNull);
  });

  test('preserves zero completed trips and supports legacy daily lists', () {
    final summary = IncomeSummary.fromJson({
      'totalTrips': 4,
      'completedTrips': 0,
      'byDay': [
        {'date': '2026-10-02', 'earnings': 25},
      ],
    });
    expect(summary.completedTrips, 0);
    expect(summary.byDay.single.amount, 25);
  });
}
