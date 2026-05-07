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
    required this.byDay,
  });

  final double totalEarnings;
  final int totalTrips;
  final List<IncomeByDay> byDay;

  factory IncomeSummary.fromJson(Map<String, dynamic> json) {
    final days = readMapList(json, ['byDay', 'days', 'series']).map(IncomeByDay.fromJson).toList();
    return IncomeSummary(
      totalEarnings: readDouble(json, ['totalEarnings', 'earnings', 'total']),
      totalTrips: readDouble(json, ['totalTrips', 'trips', 'count']).round(),
      byDay: days,
    );
  }
}