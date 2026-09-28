const Driver = require('../models/Driver');
const { computeAutoRate } = require('../services/pricingEngine');

// PATCH /api/rates/my-rate
// Blocked when rateMode is ADMIN or AUTO (algorithm owns the rate in AUTO mode)
const updateRate = async (req, res) => {
  const { ratePerKm } = req.body;
  if (ratePerKm === undefined || !Number.isFinite(Number(ratePerKm)) || Number(ratePerKm) <= 0) {
    return res.status(400).json({ message: 'ratePerKm must be a positive number' });
  }

  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Only drivers can update their own rate.' });
    }
    const driver = await Driver.findById(req.user.id).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    if (driver.pricingMode === 'ADMIN') {
      return res.status(403).json({ message: 'Rates are controlled by the regulator.' });
    }
    if (driver.pricingMode === 'AUTO') {
      return res.status(403).json({
        message: 'Auto-pricing is active. Your rate is set by the algorithm.',
        rateMode: 'AUTO',
      });
    }

    driver.ratePerKm = Number(ratePerKm);
    await driver.save();
    res.json(driver.toJSON());
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
  const overrides = {};
  const overrideFields = [
    ['baseRate', 'autoBaseRate', 1],
    ['minMultiplier', 'autoMinMultiplier', 1],
    ['maxMultiplier', 'autoMaxMultiplier', 1],
  ];
  for (const [queryField, configField, minimum] of overrideFields) {
    if (req.query[queryField] === undefined) continue;
    const value = Number(req.query[queryField]);
    if (!Number.isFinite(value) || value < minimum) {
      return res.status(400).json({ message: `${queryField} must be a number greater than or equal to ${minimum}` });
    }
    overrides[queryField] = value;
  }
  if (
    overrides.minMultiplier !== undefined &&
    overrides.maxMultiplier !== undefined &&
    overrides.minMultiplier > overrides.maxMultiplier
  ) {
    return res.status(400).json({ message: 'minMultiplier cannot exceed maxMultiplier' });
  }
  try {
    const result = await computeAutoRate(area, overrides);
    res.json({ area, ...result });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { updateRate, getAreaRates, getAutoRate };
