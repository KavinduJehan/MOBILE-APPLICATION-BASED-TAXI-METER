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

module.exports = { getConfig };