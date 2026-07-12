const Driver = require('../models/Driver');
const SystemConfig = require('../models/SystemConfig');

const updateRate = async (req, res) => {
  const { ratePerKm } = req.body;
  if (ratePerKm === undefined || ratePerKm < 0) {
    return res.status(400).json({ message: 'Valid ratePerKm is required' });
  }

  try {
    let config = await SystemConfig.findOne();
    if (!config) {
      config = await SystemConfig.create({});
    }

    if (config.rateMode === 'ADMIN') {
      return res.status(403).json({ message: 'You cannot update rates.' });
    }

    const driver = await Driver.findByIdAndUpdate(
      req.user.id,
      { ratePerKm },
      { new: true }
    ).select('-password');
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Returns average rate and list of drivers for a given area
const getAreaRates = async (req, res) => {
  const { area } = req.query;
  if (!area) return res.status(400).json({ message: 'area query parameter is required' });

  try {
    const drivers = await Driver.find({ area, isVerified: true, ratePerKm: { $gt: 0 } })
      .select('name ratePerKm vehicleNumber');

    if (drivers.length === 0) {
      return res.json({ area, averageRate: null, drivers: [] });
    }

    const total = drivers.reduce((sum, d) => sum + d.ratePerKm, 0);
    const averageRate = parseFloat((total / drivers.length).toFixed(2));

    res.json({ area, averageRate, drivers });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { updateRate, getAreaRates };
