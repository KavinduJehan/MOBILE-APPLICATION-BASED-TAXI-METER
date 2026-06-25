const SystemConfig = require('../models/SystemConfig');

const getConfig = async (req, res) => {
  try {
    let config = await SystemConfig.findOne();

    if (!config) {
      config = await SystemConfig.create({});
    }

    res.json(config);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateConfig = async (req, res) => {
  try {
    const { rateMode, registrationOpen, negotiationEnabled, onlineSearchEnabled } = req.body;
    const update = {};

    if (rateMode !== undefined) {
      const allowedModes = ['ADMIN', 'DRIVER'];
      if (!allowedModes.includes(rateMode)) {
        return res.status(400).json({ message: 'rateMode must be ADMIN or DRIVER' });
      }
      update.rateMode = rateMode;
    }

    if (registrationOpen !== undefined) {
      update.registrationOpen = registrationOpen;
    }

    if (negotiationEnabled !== undefined) {
      update.negotiationEnabled = negotiationEnabled;
    }

    if (onlineSearchEnabled !== undefined) {
      update.onlineSearchEnabled = onlineSearchEnabled;
    }

    let config = await SystemConfig.findOne();
    if (!config) {
      config = await SystemConfig.create(update);
    } else {
      Object.assign(config, update);
      await config.save();
    }

    res.json(config);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getConfig, updateConfig };