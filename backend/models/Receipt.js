const mongoose = require('mongoose');

const receiptSchema = new mongoose.Schema(
  {
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', required: true },
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true },
    receiptNumber: { type: String, required: true, unique: true },
    customerName: { type: String, default: 'Anonymous' },
    distanceKm: { type: Number, required: true },
    ratePerKm: { type: Number, required: true },
    totalFare: { type: Number, required: true },
    issuedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Receipt', receiptSchema);
