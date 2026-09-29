const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const RideRequest = require('../models/RideRequest');

const setDriverPricing = async (req, res) => {
  const { pricingMode, ratePerKm } = req.body;
  const allowedModes = ['DRIVER', 'ADMIN', 'AUTO'];
  if (!allowedModes.includes(pricingMode)) {
    return res.status(400).json({ message: 'pricingMode must be DRIVER, ADMIN, or AUTO' });
  }
  if (ratePerKm !== undefined && (!Number.isFinite(Number(ratePerKm)) || Number(ratePerKm) <= 0)) {
    return res.status(400).json({ message: 'ratePerKm must be a positive number' });
  }
  try {
    const update = { pricingMode };
    if (ratePerKm !== undefined) update.ratePerKm = Number(ratePerKm);
    const driver = await Driver.findByIdAndUpdate(req.params.id, update, { new: true, runValidators: true }).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/admin/drivers?verified=false|true|all
const listDrivers = async (req, res) => {
  const { verified } = req.query;
  try {
    let filter = {};
    if (verified === 'true') filter.isVerified = true;
    else if (verified === 'false') filter.isVerified = false;
    // 'all' or omitted → no filter

    const drivers = await Driver.find(filter).select('-password').sort({ createdAt: -1 });
    res.json(drivers);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// PATCH /api/admin/drivers/:id/verify  body: { isVerified: true|false }
const setDriverVerification = async (req, res) => {
  const { isVerified } = req.body;
  if (typeof isVerified !== 'boolean') {
    return res.status(400).json({ message: 'isVerified must be a boolean' });
  }

  try {
    const driver = await Driver.findByIdAndUpdate(
      req.params.id,
      { isVerified },
      { new: true }
    ).select('-password');

    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/admin/trips
const getAllTrips = async (req, res) => {
  try {
    const trips = await Trip.find()
      .populate('driver', 'name email vehicleNumber area')
      .sort({ createdAt: -1 });
    res.json(trips);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/admin/stats
// System-wide summary for regulators
const getStats = async (req, res) => {
  try {
    const [
      totalDrivers,
      verifiedDrivers,
      totalTrips,
      completedTrips,
      pendingRequests,
    ] = await Promise.all([
      Driver.countDocuments({ role: 'driver' }),
      Driver.countDocuments({ role: 'driver', isVerified: true }),
      Trip.countDocuments(),
      Trip.countDocuments({ status: 'completed' }),
      RideRequest.countDocuments({ status: 'pending' }),
    ]);

    // Total revenue across all completed trips
    const revenueResult = await Trip.aggregate([
      { $match: { status: 'completed' } },
      { $group: { _id: null, total: { $sum: '$totalFare' } } },
    ]);
    const totalRevenue = revenueResult.length > 0
      ? parseFloat(revenueResult[0].total.toFixed(2))
      : 0;

    res.json({
      totalDrivers,
      verifiedDrivers,
      pendingDrivers: totalDrivers - verifiedDrivers,
      totalTrips,
      completedTrips,
      pendingRideRequests: pendingRequests,
      totalRevenue,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { listDrivers, setDriverVerification, setDriverPricing, getAllTrips, getStats };
