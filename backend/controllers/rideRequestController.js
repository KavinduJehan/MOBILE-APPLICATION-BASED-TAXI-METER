const { v4: uuidv4 } = require('uuid');
const RideRequest = require('../models/RideRequest');
const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');
const SystemConfig = require('../models/SystemConfig');
const { computeAutoRate } = require('../services/pricingEngine');

const activeRideMessage =
  'You already have an active ride. Complete or cancel it before booking another ride.';

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
  const customerName = req.user.name;

  if (!driverId || pickupLat == null || pickupLng == null ||
      destLat == null || destLng == null || !estimatedDistanceKm) {
    return res.status(400).json({ message: 'driverId, pickup, destination and estimatedDistanceKm are required' });
  }

  if (estimatedDistanceKm <= 0) {
    return res.status(400).json({ message: 'estimatedDistanceKm must be greater than 0' });
  }

  try {
    const [activeRequest, activeTrip] = await Promise.all([
      RideRequest.exists({ customer: req.user.id, isActive: true }),
      Trip.exists({ customer: req.user.id, status: 'ongoing' }),
    ]);
    if (activeRequest || activeTrip) {
      return res.status(409).json({
        message: activeRideMessage,
        code: 'ACTIVE_RIDE_EXISTS',
      });
    }

    const driver = await Driver.findById(driverId);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    if (!driver.isVerified) return res.status(403).json({ message: 'Driver is not verified' });

    const config = await SystemConfig.findOne().lean();
    const effectivePricingMode = driver.pricingMode || config?.rateMode || 'ADMIN';

    // suggestedRatePerKm is a negotiation (customer proposes lower rate).
    // If it's >= driver's rate or <= 0, ignore it — no negotiation needed.
    const autoPrice = effectivePricingMode === 'AUTO'
      ? await computeAutoRate({ lat: Number(pickupLat), lng: Number(pickupLng) })
      : null;
    const currentRate = effectivePricingMode === 'ADMIN'
      ? (config?.autoBaseRate || driver.ratePerKm || 100)
      : (autoPrice?.effectiveRate ?? driver.ratePerKm);
    let effectiveSuggestion = null;
    if (effectivePricingMode === 'DRIVER' && suggestedRatePerKm != null && suggestedRatePerKm > 0 && suggestedRatePerKm < currentRate) {
      effectiveSuggestion = suggestedRatePerKm;
    }

    const rideRequest = await RideRequest.create({
      driver: driverId,
      customer: req.user.id,
      customerName,
      pickupLat,
      pickupLng,
      pickupAddress: pickupAddress || '',
      destLat,
      destLng,
      destAddress: destAddress || '',
      estimatedDistanceKm,
      driverRatePerKm: currentRate,
      suggestedRatePerKm: effectiveSuggestion,
    });

    const io = req.app?.get('io');
    if (io) {
      io.to(driverId.toString()).emit('new_request', rideRequest);
    }

    res.status(201).json(rideRequest);
  } catch (err) {
    if (err?.code === 11000) {
      return res.status(409).json({
        message: activeRideMessage,
        code: 'ACTIVE_RIDE_EXISTS',
      });
    }
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
      .populate('driver', 'name vehicleNumber vehicleType phone area ratePerKm pricingMode');
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

    const io = req.app?.get('io');

    if (action === 'reject') {
      rideRequest.status = 'rejected';
      rideRequest.isActive = false;
      await rideRequest.save();

      if (io) {
        if (rideRequest.customer) {
          io.to(rideRequest.customer.toString()).emit('request_response', {
            requestId: rideRequest._id,
            status: 'rejected',
          });
        }
        io.to(rideRequest._id.toString()).emit('request_response', {
          requestId: rideRequest._id,
          status: 'rejected',
        });
      }
      return res.json(rideRequest);
    }

    // Accept — use suggested rate if provided, otherwise driver's rate
    const driver = await Driver.findById(req.user.id);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    const config = await SystemConfig.findOne().lean();
    const effectivePricingMode = config?.rateMode || driver.pricingMode || 'ADMIN';

    let surgeBreakdown = null;
    let agreedRate = driver.ratePerKm;
    if (effectivePricingMode === 'AUTO') {
      // Use the ride request's pickup coords for accurate geofence pricing
      const priceResult = await computeAutoRate({
        lat:  rideRequest.pickupLat != null ? Number(rideRequest.pickupLat) : null,
        lng:  rideRequest.pickupLng != null ? Number(rideRequest.pickupLng) : null,
      });
      agreedRate = priceResult.effectiveRate;
      surgeBreakdown = priceResult.breakdown;
    } else if (effectivePricingMode === 'ADMIN') {
      agreedRate = config?.autoBaseRate || driver.ratePerKm || 100;
    } else if (effectivePricingMode === 'DRIVER' && rideRequest.suggestedRatePerKm != null) {
      agreedRate = rideRequest.suggestedRatePerKm;
    }
    if (!Number.isFinite(agreedRate) || agreedRate <= 0) {
      return res.status(400).json({ message: 'The driver does not have a valid rate configured' });
    }

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
      pickupLat: rideRequest.pickupLat,
      pickupLng: rideRequest.pickupLng,
      destLat: rideRequest.destLat,
      destLng: rideRequest.destLng,
      distanceKm: rideRequest.estimatedDistanceKm,
      ratePerKm: agreedRate,
      totalFare,
      surgeBreakdown,
      startTime: new Date(),
      status: 'ongoing',
    });

    rideRequest.status = 'accepted';
    rideRequest.agreedRatePerKm = agreedRate;
    rideRequest.trip = trip._id;
    await rideRequest.save();
    if (io) {
      const acceptedPayload = {
        requestId: rideRequest._id,
        status: 'accepted',
        trip,
        agreedRatePerKm: agreedRate,
        pickupAddress: rideRequest.pickupAddress,
        destAddress: rideRequest.destAddress,
        pickupLat: rideRequest.pickupLat,
        pickupLng: rideRequest.pickupLng,
        destLat: rideRequest.destLat,
        destLng: rideRequest.destLng,
      };
      if (rideRequest.customer) {
        io.to(rideRequest.customer.toString()).emit('request_response', acceptedPayload);
      }
      io.to(rideRequest._id.toString()).emit('request_response', acceptedPayload);
    }

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
