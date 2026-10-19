import 'driver_model.dart';

class CreateTripRequest {
  final String driverId;
  final String pickupLocation;
  final String dropLocation;
  final double distanceKm;
  final double ratePerKm;
  final String customerName;

  const CreateTripRequest({
    required this.driverId,
    required this.pickupLocation,
    required this.dropLocation,
    required this.distanceKm,
    required this.ratePerKm,
    required this.customerName,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'startLocation': pickupLocation,
        'endLocation': dropLocation,
        'distanceKm': distanceKm,
        'ratePerKm': ratePerKm,
        'customerName': customerName,
      };
}

class TripModel {
  final String id;
  final DriverModel? driver;
  final String driverName;
  final String vehicleNumber;
  final String pickupLocation;
  final String dropLocation;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;
  final String status;
  final DateTime? startTime;

  /// When the driver reached the pickup point.
  final DateTime? arrivedAt;

  /// When the driver started the ride with the customer on board; null while
  /// the driver is still on the way to the pickup point.
  final DateTime? pickedUpAt;
  final DateTime? endTime;
  final DateTime? createdAt;

  const TripModel({
    required this.id,
    required this.driver,
    required this.driverName,
    required this.vehicleNumber,
    required this.pickupLocation,
    required this.dropLocation,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
    required this.status,
    required this.startTime,
    this.arrivedAt,
    this.pickedUpAt,
    required this.endTime,
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final driverValue = json['driver'];
    final driverMap = driverValue is Map
        ? Map<String, dynamic>.from(driverValue)
        : <String, dynamic>{};
    final driver = driverMap.isEmpty ? null : DriverModel.fromJson(driverMap);

    return TripModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      driver: driver,
      driverName: (json['driverName'] ?? driver?.name ?? 'Driver').toString(),
      vehicleNumber:
          (json['vehicleNumber'] ?? driver?.vehicleNumber ?? '-').toString(),
      pickupLocation:
          (json['pickupLocation'] ?? json['startLocation'] ?? '').toString(),
      dropLocation:
          (json['dropLocation'] ?? json['endLocation'] ?? '').toString(),
      distanceKm: _readDouble(json['distanceKm']),
      ratePerKm: _readDouble(json['ratePerKm']),
      totalFare: _readDouble(json['totalFare'] ?? json['fare']),
      status: (json['status'] ?? 'pending').toString(),
      startTime: _readDate(json['startTime']),
      arrivedAt: _readDate(json['arrivedAt']),
      pickedUpAt: _readDate(json['pickedUpAt']),
      endTime: _readDate(json['endTime']),
      createdAt: _readDate(json['createdAt']),
    );
  }

  double get baseFare => totalFare;
  double get additionalCharges => 0;
  double get durationMinutes {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes.toDouble();
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
