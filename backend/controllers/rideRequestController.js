const { v4: uuidv4 } = require('uuid');
const RideRequest = require('../models/RideRequest');
const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');
const SystemConfig = require('../models/SystemConfig');
const { resolveEffectiveRate } = require('../services/effectiveRate');

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

    // The quoted rate — the same value the customer was shown for this driver.
    const quote = await resolveEffectiveRate(driver, config, {
      lat: Number(pickupLat),
      lng: Number(pickupLng),
    });
    const currentRate = quote.rate;
    if (!Number.isFinite(currentRate) || currentRate <= 0) {
      return res.status(400).json({ message: 'The driver does not have a valid rate configured' });
    }

    // suggestedRatePerKm is a negotiation (customer proposes lower rate).
    // If it's >= the quoted rate or <= 0, ignore it — no negotiation needed.
    // The admin's negotiationEnabled switch turns negotiation off system-wide.
    const negotiationAllowed = config?.negotiationEnabled !== false;
    let effectiveSuggestion = null;
    const suggestion = Number(suggestedRatePerKm);
    if (negotiationAllowed && suggestedRatePerKm != null && Number.isFinite(suggestion) && suggestion > 0 && suggestion < currentRate) {
      effectiveSuggestion = suggestion;
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
      surgeBreakdown: quote.breakdown,
      suggestedRatePerKm: effectiveSuggestion,
      negotiationStatus: effectiveSuggestion != null ? 'customer_offered' : 'none',
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

// Creates the trip for an accepted request at the agreed rate, marks the
// request accepted and tells the customer. Shared by the driver accepting and
// the customer agreeing to the driver's counter-offer.
const finalizeAcceptance = async ({ rideRequest, agreedRate, surgeBreakdown, io }) => {
  const totalFare = parseFloat(
    (rideRequest.estimatedDistanceKm * agreedRate).toFixed(2)
  );

  const trip = await Trip.create({
    driver: rideRequest.driver,
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
  if (rideRequest.negotiationStatus !== 'none') rideRequest.negotiationStatus = 'agreed';
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

  return trip;
};

// Tells the customer the request was turned down (by the driver, or because
// the negotiation ended without agreement).
const emitRejected = (io, rideRequest) => {
  if (!io) return;
  const payload = { requestId: rideRequest._id, status: 'rejected' };
  if (rideRequest.customer) {
    io.to(rideRequest.customer.toString()).emit('request_response', payload);
  }
  io.to(rideRequest._id.toString()).emit('request_response', payload);
};

// PATCH /api/ride-requests/:id/respond
// Driver accepts, rejects, or counters the customer's offer — requires auth
//   accept  – take the ride (at the customer's suggested rate if they made one)
//   reject  – decline the ride
//   counter – answer the customer's suggested rate with counterRatePerKm
const respondToRequest = async (req, res) => {
  const { action } = req.body;

  if (!['accept', 'reject', 'counter'].includes(action)) {
    return res.status(400).json({ message: 'action must be "accept", "reject" or "counter"' });
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
      if (rideRequest.negotiationStatus !== 'none') rideRequest.negotiationStatus = 'declined';
      await rideRequest.save();

      emitRejected(io, rideRequest);
      return res.json(rideRequest);
    }

    if (action === 'counter') {
      if (rideRequest.negotiationStatus !== 'customer_offered' || rideRequest.suggestedRatePerKm == null) {
        return res.status(409).json({
          message: rideRequest.negotiationStatus === 'driver_countered'
            ? 'You already sent an offer. Waiting for the customer to answer.'
            : 'The customer has not asked to negotiate this fare.',
        });
      }
      const counter = Number(req.body.counterRatePerKm);
      // The counter must sit above the customer's offer and never above the
      // rate the customer was originally quoted.
      if (!Number.isFinite(counter) ||
          counter <= rideRequest.suggestedRatePerKm ||
          counter > rideRequest.driverRatePerKm) {
        return res.status(400).json({
          message: `counterRatePerKm must be more than ${rideRequest.suggestedRatePerKm} and at most ${rideRequest.driverRatePerKm}`,
        });
      }

      rideRequest.counterRatePerKm = parseFloat(counter.toFixed(2));
      rideRequest.negotiationStatus = 'driver_countered';
      await rideRequest.save();

      if (io) {
        const payload = {
          requestId: rideRequest._id,
          status: 'countered',
          counterRatePerKm: rideRequest.counterRatePerKm,
          suggestedRatePerKm: rideRequest.suggestedRatePerKm,
          driverRatePerKm: rideRequest.driverRatePerKm,
          estimatedDistanceKm: rideRequest.estimatedDistanceKm,
        };
        if (rideRequest.customer) {
          io.to(rideRequest.customer.toString()).emit('request_response', payload);
        }
        io.to(rideRequest._id.toString()).emit('request_response', payload);
      }
      return res.json(rideRequest);
    }

    if (rideRequest.negotiationStatus === 'driver_countered') {
      return res.status(409).json({
        message: 'You sent the customer an offer. Wait for their answer, or reject the request.',
      });
    }

    // Accept — charge the rate the customer was quoted when they sent the
    // request, so the fare matches what both sides saw.
    let agreedRate = rideRequest.driverRatePerKm;
    let surgeBreakdown = rideRequest.surgeBreakdown ?? null;
    if (!Number.isFinite(agreedRate) || agreedRate <= 0) {
      // Requests created before quotes were stored: price it now.
      const driver = await Driver.findById(req.user.id);
      if (!driver) return res.status(404).json({ message: 'Driver not found' });
      const config = await SystemConfig.findOne().lean();
      const live = await resolveEffectiveRate(driver, config, {
        lat: Number(rideRequest.pickupLat),
        lng: Number(rideRequest.pickupLng),
      });
      agreedRate = live.rate;
      surgeBreakdown = live.breakdown;
    }
    // Accepting a request that carries the customer's offer means agreeing to it.
    if (rideRequest.suggestedRatePerKm != null) {
      agreedRate = rideRequest.suggestedRatePerKm;
      surgeBreakdown = null;
    }
    if (!Number.isFinite(agreedRate) || agreedRate <= 0) {
      return res.status(400).json({ message: 'The driver does not have a valid rate configured' });
    }

    const trip = await finalizeAcceptance({ rideRequest, agreedRate, surgeBreakdown, io });

    res.json({ rideRequest, trip });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// PATCH /api/ride-requests/:id/counter-response
// Customer answers the driver's counter-offer — requires customer auth
//   accept – agree to the counter rate; the trip starts at that rate
//   reject – decline it; the request ends
const respondToCounterOffer = async (req, res) => {
  const { action } = req.body;

  if (!['accept', 'reject'].includes(action)) {
    return res.status(400).json({ message: 'action must be "accept" or "reject"' });
  }

  try {
    const rideRequest = await RideRequest.findById(req.params.id);
    if (!rideRequest) return res.status(404).json({ message: 'Ride request not found' });

    if (!rideRequest.customer || rideRequest.customer.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Forbidden' });
    }
    if (rideRequest.status !== 'pending') {
      return res.status(409).json({ message: `Request is already ${rideRequest.status}` });
    }
    if (rideRequest.negotiationStatus !== 'driver_countered' || rideRequest.counterRatePerKm == null) {
      return res.status(409).json({ message: 'There is no driver offer to answer.' });
    }

    const io = req.app?.get('io');
    const driverRoom = rideRequest.driver.toString();

    if (action === 'reject') {
      rideRequest.status = 'rejected';
      rideRequest.isActive = false;
      rideRequest.negotiationStatus = 'declined';
      await rideRequest.save();

      if (io) {
        io.to(driverRoom).emit('negotiation_result', {
          requestId: rideRequest._id,
          status: 'declined',
        });
      }
      return res.json({ rideRequest });
    }

    const trip = await finalizeAcceptance({
      rideRequest,
      agreedRate: rideRequest.counterRatePerKm,
      surgeBreakdown: null,
      io,
    });

    if (io) {
      io.to(driverRoom).emit('negotiation_result', {
        requestId: rideRequest._id,
        status: 'accepted',
        agreedRatePerKm: rideRequest.agreedRatePerKm,
        rideRequest,
        trip,
      });
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
  respondToCounterOffer,
};
