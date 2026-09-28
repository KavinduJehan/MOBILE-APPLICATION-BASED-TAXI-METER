const mongoose = require('mongoose');

const tripSchema = new mongoose.Schema(
  {
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true },
    customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', default: null },
    customerName: { type: String, default: 'Anonymous' },
    startLocation: { type: String, required: true },
    endLocation: { type: String, required: true },
    pickupLat: { type: Number, default: null },
    pickupLng: { type: Number, default: null },
    destLat: { type: Number, default: null },
    destLng: { type: Number, default: null },
    distanceKm: { type: Number, required: true },
    ratePerKm: { type: Number, required: true },
    totalFare: { type: Number, required: true },
    // Snapshot of the surge pricing signals used when rateMode is AUTO.
    // Null for trips created under ADMIN or DRIVER modes.
    surgeBreakdown: { type: mongoose.Schema.Types.Mixed, default: null },
    startTime: { type: Date, required: true },
    endTime: { type: Date },
    status: {
      type: String,
      enum: ['pending', 'ongoing', 'completed', 'cancelled'],
      default: 'pending',
    },
    syncedToCloud: { type: Boolean, default: false },
  },
  { timestamps: true }
);

tripSchema.index(
  { customer: 1 },
  {
    unique: true,
    partialFilterExpression: {
      status: 'ongoing',
      customer: { $type: 'objectId' },
    },
  }
);

module.exports = mongoose.model('Trip', tripSchema);
