const Driver = require('../models/Driver');
const SystemConfig = require('../models/SystemConfig');
const { computeAutoRate } = require('../services/pricingEngine');

// PATCH /api/rates/my-rate
// Blocked when rateMode is ADMIN or AUTO (algorithm owns the rate in AUTO mode)
const updateRate = async (req, res) => {
  const { ratePerKm } = req.body;
  if (ratePerKm === undefined || ratePerKm < 0) {
    return res.status(400).json({ message: 'Valid ratePerKm is required' });
  }

  try {
    let config = await SystemConfig.findOne();
    if (!config) config = await SystemConfig.create({});

    if (config.rateMode === 'ADMIN') {
      return res.status(403).json({ message: 'Rates are controlled by the regulator.' });
    }
    if (config.rateMode === 'AUTO') {
      return res.status(403).json({
        message: 'Auto-pricing is active. Your rate is set by the algorithm.',
        rateMode: 'AUTO',
      });
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

// GET /api/rates/area?area=Colombo
// Returns average manual rate and driver list for an area
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

// GET /api/rates/auto?area=Colombo
// Returns the real-time auto-calculated rate with full signal breakdown.
// Public endpoint - used by both drivers (rate screen) and customers (booking).
const getAutoRate = async (req, res) => {
  const area = (req.query.area || '').trim();
  try {
    const result = await computeAutoRate(area);
    res.json({ area, ...result });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { updateRate, getAreaRates, getAutoRate };
