const SystemConfig = require('../models/SystemConfig');
const Driver = require('../models/Driver');

const getConfig = async (req, res) => {
  try {
    let config = await SystemConfig.findOne();
    if (!config) config = await SystemConfig.create({});
    res.json(config);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getPublicConfig = async (req, res) => {
  try {
    let config = await SystemConfig.findOne();
    if (!config) config = await SystemConfig.create({});

    res.json({
      rateMode:           config.rateMode,
      negotiationEnabled: config.negotiationEnabled,
      registrationOpen:   config.registrationOpen,
      onlineSearchEnabled: config.onlineSearchEnabled,
      // AUTO mode fields – clients use these to display the live rate UI
      autoBaseRate:      config.autoBaseRate,
      autoMinMultiplier: config.autoMinMultiplier,
      autoMaxMultiplier: config.autoMaxMultiplier,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateConfig = async (req, res) => {
  try {
    const {
      rateMode,
      registrationOpen,
      negotiationEnabled,
      onlineSearchEnabled,
      autoBaseRate,
      autoMinMultiplier,
      autoMaxMultiplier,
      autoAreaFactors,
    } = req.body;

    const update = {};

    if (rateMode !== undefined) {
      const allowedModes = ['ADMIN', 'DRIVER', 'AUTO'];
      if (!allowedModes.includes(rateMode)) {
        return res.status(400).json({ message: 'rateMode must be ADMIN, DRIVER, or AUTO' });
      }
      update.rateMode = rateMode;
    }
    if (registrationOpen  !== undefined) update.registrationOpen  = registrationOpen;
    if (negotiationEnabled !== undefined) update.negotiationEnabled = negotiationEnabled;
    if (onlineSearchEnabled !== undefined) update.onlineSearchEnabled = onlineSearchEnabled;

    // AUTO pricing fields
    if (autoBaseRate !== undefined) {
      if (typeof autoBaseRate !== 'number' || autoBaseRate <= 0) {
        return res.status(400).json({ message: 'autoBaseRate must be a positive number' });
      }
      update.autoBaseRate = autoBaseRate;
    }
    if (autoMinMultiplier !== undefined) {
      if (typeof autoMinMultiplier !== 'number' || autoMinMultiplier < 1) {
        return res.status(400).json({ message: 'autoMinMultiplier must be >= 1' });
      }
      update.autoMinMultiplier = autoMinMultiplier;
    }
    if (autoMaxMultiplier !== undefined) {
      if (typeof autoMaxMultiplier !== 'number' || autoMaxMultiplier < 1) {
        return res.status(400).json({ message: 'autoMaxMultiplier must be >= 1' });
      }
      update.autoMaxMultiplier = autoMaxMultiplier;
    }
    if (autoAreaFactors !== undefined) {
      if (typeof autoAreaFactors !== 'object' || Array.isArray(autoAreaFactors)) {
        return res.status(400).json({ message: 'autoAreaFactors must be a key-value object' });
      }
      update.autoAreaFactors = autoAreaFactors;
    }

    let config = await SystemConfig.findOne();
    if (!config) {
      config = await SystemConfig.create(update);
    } else {
      Object.assign(config, update);
      await config.save();
    }

    if (rateMode !== undefined) {
      await Driver.updateMany({}, { $set: { pricingMode: rateMode } });
    }

    res.json(config);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getConfig, getPublicConfig, updateConfig };