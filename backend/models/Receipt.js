const mongoose = require('mongoose');

const receiptSchema = new mongoose.Schema(
  {
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', required: true },
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true },
    receiptNumber: { type: String, required: true, unique: true },
    customerName: { type: String, default: 'Anonymous' },
    startLocation: { type: String, default: '' },
    endLocation: { type: String, default: '' },
    distanceKm: { type: Number, required: true },
    durationMinutes: { type: Number, default: 0 },
    baseFare: { type: Number, default: 0 },
    additionalCharges: { type: Number, default: 0 },
    ratePerKm: { type: Number, required: true },
    totalFare: { type: Number, required: true },
    paymentMethod: { type: String, default: 'Cash' },
    issuedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Receipt', receiptSchema);
