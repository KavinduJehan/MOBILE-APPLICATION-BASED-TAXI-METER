const mongoose = require('mongoose');

const tripSchema = new mongoose.Schema(
  {
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true },
    customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', default: null },
    customerName: { type: String, default: 'Anonymous' },
    startLocation: { type: String, required: true },
    endLocation: { type: String, required: true },
    distanceKm: { type: Number, required: true },
    ratePerKm: { type: Number, required: true },
    totalFare: { type: Number, required: true },
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
