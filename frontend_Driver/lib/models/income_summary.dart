import '../utils/json_helpers.dart';

class IncomeByDay {
  IncomeByDay({required this.label, required this.amount});

  final String label;
  final double amount;

  factory IncomeByDay.fromJson(Map<String, dynamic> json) {
    return IncomeByDay(
      label: readString(json, ['label', 'day', 'date']),
      amount: readDouble(json, ['amount', 'earnings', 'value']),
    );
  }
}

class IncomeSummary {
  IncomeSummary({
    required this.totalEarnings,
    required this.totalTrips,
    this.completedTrips = 0,
    this.cancelledTrips = 0,
    required this.byDay,
  });

  final double totalEarnings;
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final List<IncomeByDay> byDay;

  factory IncomeSummary.fromJson(Map<String, dynamic> json) {
    final days = readMapList(json, ['byDay', 'days', 'series']).map(IncomeByDay.fromJson).toList();
    final total = readDouble(json, ['totalTrips', 'trips', 'count']).round();
    final completed = readDouble(json, ['completedTrips', 'completed']).round();
    final cancelled = readDouble(json, ['cancelledTrips', 'canceledTrips', 'cancelled']).round();
    return IncomeSummary(
      totalEarnings: readDouble(json, ['totalEarnings', 'earnings', 'total']),
      totalTrips: total,
      completedTrips: completed > 0 ? completed : total,
      cancelledTrips: cancelled,
      byDay: days,
    );
  }
}