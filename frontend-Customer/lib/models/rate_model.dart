class AreaRateModel {
  final String areaName;
  final double? baseFare;
  final double? perKmCharge;
  final double? waitingCharge;
  final double surgeMultiplier;
  final DateTime? lastUpdatedAt;

  const AreaRateModel({
    required this.areaName,
    required this.baseFare,
    required this.perKmCharge,
    required this.waitingCharge,
    required this.surgeMultiplier,
    required this.lastUpdatedAt,
  });

  factory AreaRateModel.fromJson(Map<String, dynamic> json) => AreaRateModel(
        areaName: (json['areaName'] ?? json['area'] ?? '').toString(),
        baseFare: _readDouble(json['baseFare']),
        perKmCharge: _readDouble(json['perKmCharge'] ?? json['averageRate']),
        waitingCharge: _readDouble(json['waitingCharge']),
        surgeMultiplier: _readDouble(json['surgeMultiplier']) ?? 1,
        lastUpdatedAt: DateTime.tryParse(
          (json['lastUpdatedAt'] ?? json['updatedAt'] ?? '').toString(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'areaName': areaName,
        'baseFare': baseFare,
        'perKmCharge': perKmCharge,
        'waitingCharge': waitingCharge,
        'surgeMultiplier': surgeMultiplier,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      };

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
