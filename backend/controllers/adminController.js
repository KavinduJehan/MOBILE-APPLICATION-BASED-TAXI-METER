const Driver = require('../models/Driver');
const Trip = require('../models/Trip');

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

module.exports = { listDrivers, setDriverVerification, getAllTrips };
