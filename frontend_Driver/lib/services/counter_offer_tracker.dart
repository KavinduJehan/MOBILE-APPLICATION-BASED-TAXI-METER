import '../models/ride_request.dart';

/// Remembers ride requests where this driver has sent the customer a
/// counter-offer and is still waiting for the answer, so the answer is picked
/// up even after the driver leaves the request screen.
class CounterOfferTracker {
  CounterOfferTracker._();
  static final CounterOfferTracker instance = CounterOfferTracker._();

  final Map<String, RideRequest> _waiting = {};

  /// The request currently open on the review screen; that screen watches it
  /// itself, so the home screen skips it.
  String? activeRequestId;

  void add(RideRequest request) => _waiting[request.id] = request;

  void remove(String requestId) => _waiting.remove(requestId);

  List<RideRequest> get waitingElsewhere => _waiting.values
      .where((request) => request.id != activeRequestId)
      .toList();
}
