import 'trip_record.dart';

class TripCompletionResult {
  TripCompletionResult({required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;
}