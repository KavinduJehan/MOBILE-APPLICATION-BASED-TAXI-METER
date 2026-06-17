const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema(
  {
    rateMode: { type: String, enum: ['ADMIN', 'DRIVER'], default: 'ADMIN' },
    registrationOpen: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SystemConfig', systemConfigSchema);