import '../utils/json_helpers.dart';
import 'ride_request.dart';

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
    this.surgeBreakdown,
    this.offlineLocalId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.startedAt,
    this.arrivedAt,
    this.pickedUpAt,
  });

  final String id;
  final String? offlineLocalId;
  final String customerName;
  final String startAddress;
  final String endAddress;
  final double distanceKm;
  final double ratePerKm;
  final double fare;
  final String status;
  final DateTime? date;
  final String? receiptNumber;

  /// Coordinates and progress timestamps, present for online trips. They let an
  /// interrupted trip be resumed from where the driver left off.
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final DateTime? startedAt;
  final DateTime? arrivedAt;
  final DateTime? pickedUpAt;

  /// Non-null when the trip was priced under AUTO mode.
  final Map<String, dynamic>? surgeBreakdown;

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    return TripRecord(
      id: readString(json, ['id', '_id', 'tripId']),
      offlineLocalId: json['offlineLocalId'] as String?,
      customerName: readString(json, [
        'customerName',
        'passengerName',
      ], fallback: 'Customer'),
      startAddress: readString(json, [
        'startAddress',
        'startLocation',
        'pickupAddress',
        'pickup',
      ]),
      endAddress: readString(json, [
        'endAddress',
        'endLocation',
        'destinationAddress',
        'destination',
      ]),
      distanceKm: readDouble(json, ['distanceKm', 'distance']),
      ratePerKm: readDouble(json, ['ratePerKm', 'rate']),
      fare: readDouble(json, ['fare', 'totalFare', 'amount']),
      status: readString(json, ['status'], fallback: 'completed'),
      date: readDateTime(json, [
        'endTime',
        'completedAt',
        'endedAt',
        'date',
        'createdAt',
      ]),
      receiptNumber: readString(json, [
        'receiptNumber',
        'receiptId',
      ], fallback: ''),
      surgeBreakdown: readMap(json, ['surgeBreakdown']),
      pickupLatitude: (json['pickupLat'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLng'] as num?)?.toDouble(),
      destinationLatitude: (json['destLat'] as num?)?.toDouble(),
      destinationLongitude: (json['destLng'] as num?)?.toDouble(),
      startedAt: readDateTime(json, ['startTime']),
      arrivedAt: readDateTime(json, ['arrivedAt']),
      pickedUpAt: readDateTime(json, ['pickedUpAt']),
    );
  }

  double get estimatedFare => distanceKm * ratePerKm;

  /// An online trip the driver has accepted and not yet finished.
  bool get isOngoing => offlineLocalId == null && status == 'ongoing';

  bool get canResumeNavigation =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      destinationLatitude != null &&
      destinationLongitude != null;

  /// Rebuilds the request the navigation screen needs from the saved trip.
  RideRequest toResumeRequest() => RideRequest(
    id: id,
    customerName: customerName,
    pickupAddress: startAddress,
    destinationAddress: endAddress,
    pickupLatitude: pickupLatitude ?? 0,
    pickupLongitude: pickupLongitude ?? 0,
    destinationLatitude: destinationLatitude ?? 0,
    destinationLongitude: destinationLongitude ?? 0,
    estimatedDistanceKm: distanceKm,
    driverRatePerKm: ratePerKm,
    suggestedRatePerKm: null,
    status: 'accepted',
    createdAt: startedAt ?? date,
  );
  TripRecord copyWith({
    String? id,
    String? customerName,
    String? startAddress,
    String? endAddress,
    double? distanceKm,
    double? ratePerKm,
    double? fare,
    String? status,
    DateTime? date,
    String? receiptNumber,
    Map<String, dynamic>? surgeBreakdown,
  }) {
    return TripRecord(
      id: id ?? this.id,
      offlineLocalId: offlineLocalId,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      startedAt: startedAt,
      arrivedAt: arrivedAt,
      pickedUpAt: pickedUpAt,
      customerName: customerName ?? this.customerName,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      ratePerKm: ratePerKm ?? this.ratePerKm,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      date: date ?? this.date,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      surgeBreakdown: surgeBreakdown ?? this.surgeBreakdown,
    );
  }
}
