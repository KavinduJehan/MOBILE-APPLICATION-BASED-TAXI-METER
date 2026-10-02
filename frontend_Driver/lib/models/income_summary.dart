import '../utils/json_helpers.dart';

class IncomeByDay {
  IncomeByDay({required this.label, required this.amount, this.trips});

  final String label;
  final double amount;
  final int? trips;
  DateTime? get date => DateTime.tryParse(label);

  factory IncomeByDay.fromJson(Map<String, dynamic> json) => IncomeByDay(
    label: readString(json, ['label', 'day', 'date']),
    amount: readDouble(json, ['amount', 'earnings', 'value']),
    trips: json['trips'] is num ? (json['trips'] as num).toInt() : null,
  );
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
    final raw = json['byDay'];
    final counts = json['tripsByDay'];
    final days = raw is Map
        ? raw.entries
              .map(
                (entry) => IncomeByDay(
                  label: entry.key.toString(),
                  amount: num.tryParse('${entry.value}')?.toDouble() ?? 0,
                  trips: counts is Map && counts[entry.key] is num
                      ? (counts[entry.key] as num).toInt()
                      : null,
                ),
              )
              .toList()
        : readMapList(json, [
            'byDay',
            'days',
            'series',
          ]).map(IncomeByDay.fromJson).toList();
    days.sort((a, b) => a.label.compareTo(b.label));
    final total = readDouble(json, ['totalTrips', 'trips', 'count']).round();
    return IncomeSummary(
      totalEarnings: readDouble(json, ['totalEarnings', 'earnings', 'total']),
      totalTrips: total,
      completedTrips: readDouble(json, [
        'completedTrips',
        'completed',
      ], fallback: total.toDouble()).round(),
      cancelledTrips: readDouble(json, [
        'cancelledTrips',
        'canceledTrips',
        'cancelled',
      ]).round(),
      byDay: days,
    );
  }

  /// Rolling calendar days, including today and days without completed rides.
  List<IncomeByDay> daysForPeriod(int length, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final amounts = <String, IncomeByDay>{
      for (final day in byDay) day.label: day,
    };
    final hasCounts = byDay.every((day) => day.trips != null);
    return List.generate(length, (index) {
      final date = DateTime(
        today.year,
        today.month,
        today.day - length + index + 1,
      );
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return amounts[key] ??
          IncomeByDay(label: key, amount: 0, trips: hasCounts ? 0 : null);
    });
  }
}
