import '../utils/json_helpers.dart';

class TripRecord {
  TripRecord({
    required this.id,
    required this.customerName,
    required this.startAddress,
    required this.endAddress,
    required this.distanceKm,
    required this.ratePerKm,
    required this.fare,
    required this.status,
    required this.date,
    this.receiptNumber,
  });

  final String id;
  final String customerName;
  final String startAddress;
  final String endAddress;
  final double distanceKm;
  final double ratePerKm;
  final double fare;
  final String status;
  final DateTime? date;
  final String? receiptNumber;

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    return TripRecord(
      id: readString(json, ['id', '_id', 'tripId']),
      customerName: readString(json, ['customerName', 'passengerName'], fallback: 'Customer'),
      startAddress: readString(json, ['startAddress', 'pickupAddress', 'pickup']),
      endAddress: readString(json, ['endAddress', 'destinationAddress', 'destination']),
      distanceKm: readDouble(json, ['distanceKm', 'distance']),
      ratePerKm: readDouble(json, ['ratePerKm', 'rate']),
      fare: readDouble(json, ['fare', 'totalFare', 'amount']),
      status: readString(json, ['status'], fallback: 'completed'),
      date: readDateTime(json, ['date', 'createdAt', 'completedAt', 'endedAt']),
      receiptNumber: readString(json, ['receiptNumber', 'receiptId'], fallback: ''),
    );
  }

  double get estimatedFare => distanceKm * ratePerKm;
}