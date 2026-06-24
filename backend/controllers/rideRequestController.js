const { v4: uuidv4 } = require('uuid');
const RideRequest = require('../models/RideRequest');
const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');

// POST /api/ride-requests
// Customer creates a ride request — requires customer JWT (name pulled from token)
const createRideRequest = async (req, res) => {
  const {
    driverId,
    pickupLat,
    pickupLng,
    pickupAddress,
    destLat,
    destLng,
    destAddress,
    estimatedDistanceKm,
    suggestedRatePerKm,
  } = req.body;

  // Customer name comes from the verified JWT — not from the request body
  const customerName = req.user?.name || req.body.customerName || 'Anonymous';

  if (!driverId || pickupLat == null || pickupLng == null ||
      destLat == null || destLng == null || !estimatedDistanceKm) {
    return res.status(400).json({ message: 'driverId, pickup, destination and estimatedDistanceKm are required' });
  }

  if (estimatedDistanceKm <= 0) {
    return res.status(400).json({ message: 'estimatedDistanceKm must be greater than 0' });
  }

  try {
    const driver = await Driver.findById(driverId);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    if (!driver.isVerified) return res.status(403).json({ message: 'Driver is not verified' });

    // suggestedRatePerKm is a negotiation (customer proposes lower rate).
    // If it's >= driver's rate or <= 0, ignore it — no negotiation needed.
    let effectiveSuggestion = null;
    if (suggestedRatePerKm != null && suggestedRatePerKm > 0 && suggestedRatePerKm < driver.ratePerKm) {
      effectiveSuggestion = suggestedRatePerKm;
    }

    const rideRequest = await RideRequest.create({
      driver: driverId,
      customer: req.user?.role === 'customer' ? req.user.id : null,
      customerName,
      pickupLat,
      pickupLng,
      pickupAddress: pickupAddress || '',
      destLat,
      destLng,
      destAddress: destAddress || '',
      estimatedDistanceKm,
      driverRatePerKm: driver.ratePerKm,
      suggestedRatePerKm: effectiveSuggestion,
    });

    res.status(201).json(rideRequest);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/ride-requests/incoming
// Driver polls for pending requests sent to them — requires auth
const getIncomingRequests = async (req, res) => {
  try {
    const requests = await RideRequest.find({
      driver: req.user.id,
      status: 'pending',
    }).sort({ createdAt: -1 });
    res.json(requests);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/ride-requests/:id/status
// Customer polls for the status of their request — no auth required
const getRequestStatus = async (req, res) => {
  try {
    const rideRequest = await RideRequest.findById(req.params.id)
      .populate('trip', 'driver customer customerName startLocation endLocation distanceKm ratePerKm totalFare status startTime endTime createdAt')
      .populate('driver', 'name vehicleNumber vehicleType phone area ratePerKm');
    if (!rideRequest) return res.status(404).json({ message: 'Ride request not found' });
    res.json(rideRequest);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// PATCH /api/ride-requests/:id/respond
// Driver accepts or rejects a request — requires auth
const respondToRequest = async (req, res) => {
  const { action } = req.body; // 'accept' or 'reject'

  if (!['accept', 'reject'].includes(action)) {
    return res.status(400).json({ message: 'action must be "accept" or "reject"' });
  }

  try {
    const rideRequest = await RideRequest.findById(req.params.id);
    if (!rideRequest) return res.status(404).json({ message: 'Ride request not found' });

    if (rideRequest.driver.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    if (rideRequest.status !== 'pending') {
      return res.status(409).json({ message: `Request is already ${rideRequest.status}` });
    }

    if (action === 'reject') {
      rideRequest.status = 'rejected';
      await rideRequest.save();
      return res.json(rideRequest);
    }

    // Accept — use suggested rate if provided, otherwise driver's rate
    const agreedRate = rideRequest.suggestedRatePerKm != null
      ? rideRequest.suggestedRatePerKm
      : rideRequest.driverRatePerKm;

    const totalFare = parseFloat(
      (rideRequest.estimatedDistanceKm * agreedRate).toFixed(2)
    );

    // Auto-create the trip
    const trip = await Trip.create({
      driver: req.user.id,
      customer: rideRequest.customer || null,
      customerName: rideRequest.customerName,
      startLocation: rideRequest.pickupAddress || `${rideRequest.pickupLat},${rideRequest.pickupLng}`,
      endLocation: rideRequest.destAddress || `${rideRequest.destLat},${rideRequest.destLng}`,
      distanceKm: rideRequest.estimatedDistanceKm,
      ratePerKm: agreedRate,
      totalFare,
      startTime: new Date(),
      status: 'ongoing',
    });

    rideRequest.status = 'accepted';
    rideRequest.agreedRatePerKm = agreedRate;
    rideRequest.trip = trip._id;
    await rideRequest.save();

    res.json({ rideRequest, trip });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  createRideRequest,
  getIncomingRequests,
  getRequestStatus,
  respondToRequest,
};
