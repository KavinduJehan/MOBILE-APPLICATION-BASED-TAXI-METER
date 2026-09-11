const { v4: uuidv4 } = require('uuid');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');
const Driver = require('../models/Driver');

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
  const { driverId, startLocation, endLocation, distanceKm, ratePerKm, customerName, startTime } = req.body;
  if (!startLocation || !endLocation || !distanceKm || !ratePerKm) {
    return res.status(400).json({ message: 'Missing required trip fields' });
  }

  try {
    const resolvedDriverId = isCustomer(req) ? driverId : req.user.id;
    if (!resolvedDriverId) {
      return res.status(400).json({ message: 'driverId is required' });
    }

    const driver = await Driver.findById(resolvedDriverId);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    if (isCustomer(req) && !driver.isVerified) {
      return res.status(403).json({ message: 'Driver is not verified' });
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
      startTime: startTime || new Date(),
      status: 'ongoing',
    });
    res.status(201).json(await populateTrip(Trip.findById(trip._id)));
  } catch (err) {
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

    res.json({ totalEarnings, totalTrips, byDay });
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
};
