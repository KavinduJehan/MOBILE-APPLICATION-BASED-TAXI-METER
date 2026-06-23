import 'trip_model.dart';

class ReceiptModel {
  final String id;
  final String receiptNumber;
  final String tripId;
  final String driverName;
  final String vehicleNumber;
  final String pickupLocation;
  final String dropLocation;
  final double distanceKm;
  final double durationMinutes;
  final double baseFare;
  final double additionalCharges;
  final double totalFare;
  final String paymentMethod;
  final DateTime? issuedAt;

  const ReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.tripId,
    required this.driverName,
    required this.vehicleNumber,
    required this.pickupLocation,
    required this.dropLocation,
    required this.distanceKm,
    required this.durationMinutes,
    required this.baseFare,
    required this.additionalCharges,
    required this.totalFare,
    required this.paymentMethod,
    required this.issuedAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final tripValue = json['trip'];
    final tripMap = tripValue is Map ? Map<String, dynamic>.from(tripValue) : null;
    final driverMap = json['driver'] is Map
        ? Map<String, dynamic>.from(json['driver'] as Map)
        : null;
    final tripId = tripValue is Map
        ? (tripValue['_id'] ?? tripValue['id'] ?? '').toString()
        : (tripValue ?? json['tripId'] ?? '').toString();

    return ReceiptModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      receiptNumber: (json['receiptNumber'] ?? json['number'] ?? '-').toString(),
      tripId: tripId,
      driverName: (json['driverName'] ?? driverMap?['name'] ?? 'Driver').toString(),
      vehicleNumber:
          (json['vehicleNumber'] ?? driverMap?['vehicleNumber'] ?? '-').toString(),
      pickupLocation:
          (json['pickupLocation'] ?? json['startLocation'] ?? tripMap?['startLocation'] ?? '-')
              .toString(),
      dropLocation:
          (json['dropLocation'] ?? json['endLocation'] ?? tripMap?['endLocation'] ?? '-')
              .toString(),
      distanceKm: _readDouble(json['distanceKm']),
      durationMinutes: _readDouble(json['durationMinutes']),
      baseFare: _readDouble(json['baseFare'] ?? json['totalFare']),
      additionalCharges: _readDouble(json['additionalCharges']),
      totalFare: _readDouble(json['totalFare']),
      paymentMethod: (json['paymentMethod'] ?? 'Cash').toString(),
      issuedAt: DateTime.tryParse(
        (json['issuedAt'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }

  factory ReceiptModel.fromTrip(TripModel trip) => ReceiptModel(
        id: trip.id,
        receiptNumber: 'Pending',
        tripId: trip.id,
        driverName: trip.driverName,
        vehicleNumber: trip.vehicleNumber,
        pickupLocation: trip.pickupLocation,
        dropLocation: trip.dropLocation,
        distanceKm: trip.distanceKm,
        durationMinutes: trip.durationMinutes,
        baseFare: trip.baseFare,
        additionalCharges: trip.additionalCharges,
        totalFare: trip.totalFare,
        paymentMethod: 'Cash',
        issuedAt: trip.endTime ?? trip.createdAt,
      );

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
