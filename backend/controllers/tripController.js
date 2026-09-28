const { v4: uuidv4 } = require('uuid');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');
const Driver = require('../models/Driver');
const RideRequest = require('../models/RideRequest');
const SystemConfig = require('../models/SystemConfig');
const { computeAutoRate } = require('../services/pricingEngine');

const activeRideMessage =
  'You already have an active ride. Complete or cancel it before booking another ride.';

const isCustomer = (req) => req.user?.role === 'customer';
const isDriver = (req) => req.user?.role === 'driver' || !req.user?.role;

const canAccessTrip = (trip, req) => {
  const userId = req.user.id;
  const driverId = trip.driver?._id || trip.driver;
  const customerId = trip.customer?._id || trip.customer;
  return (
    driverId?.toString() === userId ||
    customerId?.toString() === userId
  );
};

const populateTrip = (query) =>
  query.populate('driver', 'name vehicleNumber vehicleType phone area ratePerKm');

const createReceiptForTrip = async (trip) => {
  const durationMinutes = trip.endTime && trip.startTime
    ? Math.max(0, Math.round((trip.endTime - trip.startTime) / 60000))
    : 0;

  return Receipt.create({
    trip: trip._id,
    driver: trip.driver,
    receiptNumber: `RCP-${uuidv4().split('-')[0].toUpperCase()}`,
    customerName: trip.customerName,
    startLocation: trip.startLocation,
    endLocation: trip.endLocation,
    distanceKm: trip.distanceKm,
    durationMinutes,
    baseFare: trip.totalFare,
    additionalCharges: 0,
    ratePerKm: trip.ratePerKm,
    totalFare: trip.totalFare,
    paymentMethod: 'Cash',
  });
};

const createTrip = async (req, res) => {
  const { driverId, startLocation, endLocation, distanceKm, customerName, startTime } = req.body;
  let { ratePerKm } = req.body;

  if (!startLocation || !endLocation || !distanceKm) {
    return res.status(400).json({ message: 'Missing required trip fields' });
  }

  try {
    const resolvedDriverId = isCustomer(req) ? driverId : req.user.id;
    if (!resolvedDriverId) {
      return res.status(400).json({ message: 'driverId is required' });
    }

    if (isCustomer(req)) {
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
    }

    const driver = await Driver.findById(resolvedDriverId);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    if (isCustomer(req) && !driver.isVerified) {
      return res.status(403).json({ message: 'Driver is not verified' });
    }

    // AUTO mode: override whatever ratePerKm was sent with the algorithm result
    let surgeBreakdown = null;
    const config = await SystemConfig.findOne();
    if (config?.rateMode === 'AUTO') {
      const priceResult = await computeAutoRate(driver.area || '');
      ratePerKm     = priceResult.effectiveRate;
      surgeBreakdown = priceResult.breakdown;
    } else if (!ratePerKm) {
      return res.status(400).json({ message: 'ratePerKm is required' });
    }

    const totalFare = parseFloat((distanceKm * ratePerKm).toFixed(2));
    const trip = await Trip.create({
      driver: resolvedDriverId,
      customer: isCustomer(req) ? req.user.id : null,
      customerName: customerName || req.user.name || 'Anonymous',
      startLocation,
      endLocation,
      distanceKm,
      ratePerKm,
      totalFare,
      surgeBreakdown,
      startTime: startTime || new Date(),
      status: 'ongoing',
    });
    res.status(201).json(await populateTrip(Trip.findById(trip._id)));
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

const startTrip = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.id);
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (!canAccessTrip(trip, req)) return res.status(403).json({ message: 'Forbidden' });
    if (trip.status === 'completed' || trip.status === 'cancelled') {
      return res.status(409).json({
        message:
          trip.status === 'completed'
            ? 'Trip is already completed'
            : 'Canceled trips cannot be started',
      });
    }

    trip.status = 'ongoing';
    trip.startTime = trip.startTime || new Date();
    await trip.save();

    res.json({ trip: await populateTrip(Trip.findById(trip._id)) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const endTrip = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.id);
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (!canAccessTrip(trip, req)) return res.status(403).json({ message: 'Forbidden' });
    if (trip.status === 'completed') {
      const existingReceipt = await Receipt.findOne({ trip: trip._id });
      return res.json({
        trip: await populateTrip(Trip.findById(trip._id)),
        receipt: existingReceipt,
      });
    }

    trip.status = 'completed';
    trip.endTime = new Date();
    await trip.save();

    await RideRequest.updateMany(
      { trip: trip._id, isActive: true },
      { $set: { isActive: false } }
    );

    const receipt = await createReceiptForTrip(trip);

    res.json({ trip: await populateTrip(Trip.findById(trip._id)), receipt });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const cancelTrip = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.id);
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (!canAccessTrip(trip, req)) {
      return res.status(403).json({ message: 'Forbidden' });
    }
    if (trip.status === 'completed') {
      return res.status(409).json({ message: 'Completed trips cannot be canceled' });
    }
    if (trip.status === 'cancelled') {
      return res.status(409).json({
        message: 'Canceled trips cannot be completed',
      });
    }
    if (trip.status === 'cancelled') {
      return res.json({ trip: await populateTrip(Trip.findById(trip._id)) });
    }

    trip.status = 'cancelled';
    trip.endTime = new Date();
    await trip.save();

    await RideRequest.updateMany(
      { trip: trip._id, isActive: true },
      { $set: { isActive: false } }
    );

    return res.json({ trip: await populateTrip(Trip.findById(trip._id)) });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

const getTripDetails = async (req, res) => {
  try {
    const trip = await populateTrip(Trip.findById(req.params.id));
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (!canAccessTrip(trip, req)) return res.status(403).json({ message: 'Forbidden' });
    res.json(trip);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getMyTrips = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
    const filter = isCustomer(req)
      ? { customer: req.user.id }
      : { driver: req.user.id };

    const trips = await populateTrip(
      Trip.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
    );
    res.json(trips);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/trips/income
// Returns the logged-in driver's earnings summary
const getIncome = async (req, res) => {
  try {
    const trips = await Trip.find({ driver: req.user.id, status: 'completed' });
    const cancelledTrips = await Trip.countDocuments({
      driver: req.user.id,
      status: { $in: ['cancelled', 'canceled'] },
    });

    const totalEarnings = parseFloat(
      trips.reduce((sum, t) => sum + t.totalFare, 0).toFixed(2)
    );
    const totalTrips = trips.length;

    // Group earnings by calendar date (YYYY-MM-DD)
    const byDay = {};
    for (const t of trips) {
      const day = t.endTime
        ? t.endTime.toISOString().slice(0, 10)
        : t.createdAt.toISOString().slice(0, 10);
      byDay[day] = parseFloat(((byDay[day] || 0) + t.totalFare).toFixed(2));
    }

    res.json({
      totalEarnings,
      totalTrips,
      completedTrips: totalTrips,
      cancelledTrips,
      byDay,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/trips/sync
// Receives an array of offline-recorded trips and saves them to MongoDB
const syncOfflineTrips = async (req, res) => {
  const { trips } = req.body;
  if (!Array.isArray(trips) || trips.length === 0) {
    return res.status(400).json({ message: 'trips array is required and must not be empty' });
  }

  try {
    const syncedTrips = [];
    const idMap = {}; // localId -> serverId

    for (const item of trips) {
      const receiptNo = item.receiptNumber || `REC-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`;

      const existingReceipt = await Receipt.findOne({ receiptNumber: receiptNo });
      if (existingReceipt) {
        if (item.localId) {
          idMap[item.localId] = existingReceipt.trip.toString();
        }
        continue;
      }

      const distanceKm = Number(item.distanceKm) || 0;
      const ratePerKm = Number(item.ratePerKm) || 0;
      const totalFare = Number(item.totalFare || item.fare) || parseFloat((distanceKm * ratePerKm).toFixed(2));
      const startTime = item.startTime ? new Date(item.startTime) : (item.date ? new Date(item.date) : new Date());
      const endTime = item.endTime ? new Date(item.endTime) : new Date();

      const trip = new Trip({
        driver: req.user.id,
        customerName: item.customerName || 'Offline Passenger',
        startLocation: item.startLocation || item.startAddress || 'Offline Pickup',
        endLocation: item.endLocation || item.endAddress || 'Offline Destination',
        distanceKm,
        ratePerKm,
        totalFare,
        startTime,
        endTime,
        status: item.status || 'completed',
        surgeBreakdown: item.surgeBreakdown || null,
        syncedToCloud: true,
      });

      await trip.save();

      const receipt = new Receipt({
        trip: trip._id,
        driver: req.user.id,
        receiptNumber: receiptNo,
        customerName: trip.customerName,
        startLocation: trip.startLocation,
        endLocation: trip.endLocation,
        distanceKm: trip.distanceKm,
        ratePerKm: trip.ratePerKm,
        totalFare: trip.totalFare,
        issuedAt: endTime,
      });

      await receipt.save();

      if (item.localId) {
        idMap[item.localId] = trip._id.toString();
      }

      syncedTrips.push({
        localId: item.localId,
        serverId: trip._id,
        receiptNumber: receiptNo,
        totalFare: trip.totalFare,
      });
    }

    res.status(200).json({
      success: true,
      syncedCount: syncedTrips.length,
      syncedTrips,
      idMap,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  createTrip,
  startTrip,
  endTrip,
  cancelTrip,
  getTripDetails,
  getMyTrips,
  getIncome,
  syncOfflineTrips,
};
