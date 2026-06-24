const { v4: uuidv4 } = require('uuid');
const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');

const createTrip = async (req, res) => {
  const { startLocation, endLocation, distanceKm, ratePerKm, customerName, startTime } = req.body;
  if (!startLocation || !endLocation || !distanceKm || !ratePerKm) {
    return res.status(400).json({ message: 'Missing required trip fields' });
  }

  try {
    const totalFare = parseFloat((distanceKm * ratePerKm).toFixed(2));
    const trip = await Trip.create({
      driver: req.user.id,
      customerName: customerName || 'Anonymous',
      startLocation,
      endLocation,
      distanceKm,
      ratePerKm,
      totalFare,
      startTime: startTime || new Date(),
      status: 'ongoing',
    });
    res.status(201).json(trip);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const endTrip = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.id);
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (trip.driver.toString() !== req.user.id) return res.status(403).json({ message: 'Forbidden' });

    trip.status = 'completed';
    trip.endTime = new Date();
    await trip.save();

    // Auto-generate receipt
    const receipt = await Receipt.create({
      trip: trip._id,
      driver: trip.driver,
      receiptNumber: `RCP-${uuidv4().split('-')[0].toUpperCase()}`,
      customerName: trip.customerName,
      distanceKm: trip.distanceKm,
      ratePerKm: trip.ratePerKm,
      totalFare: trip.totalFare,
    });

    res.json({ trip, receipt });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getMyTrips = async (req, res) => {
  try {
    const trips = await Trip.find({ driver: req.user.id }).sort({ createdAt: -1 });
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

module.exports = { createTrip, endTrip, getMyTrips, getIncome };
