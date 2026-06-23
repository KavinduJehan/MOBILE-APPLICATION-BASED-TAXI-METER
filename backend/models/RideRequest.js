const mongoose = require('mongoose');

const rideRequestSchema = new mongoose.Schema(
  {
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true },
    customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', default: null },

    // Customer info — anonymous by default
    customerName: { type: String, default: 'Anonymous' },

    // Pickup coordinates and optional human-readable address
    pickupLat: { type: Number, required: true },
    pickupLng: { type: Number, required: true },
    pickupAddress: { type: String, default: '' },

    // Destination coordinates and optional human-readable address
    destLat: { type: Number, required: true },
    destLng: { type: Number, required: true },
    destAddress: { type: String, default: '' },

    // Distance calculated on device using Haversine × 1.25 road factor
    estimatedDistanceKm: { type: Number, required: true },

    // Driver's rate at the time the request was made
    driverRatePerKm: { type: Number, required: true },

    // Customer's negotiated rate — null means no negotiation (accept driver's rate)
    suggestedRatePerKm: { type: Number, default: null },

    // Agreed rate — set when driver accepts (either driverRatePerKm or suggestedRatePerKm)
    agreedRatePerKm: { type: Number, default: null },

    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'expired'],
      default: 'pending',
    },

    // Populated when driver accepts — links to the created Trip
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', default: null },

    // Reserved for future offline sync
    syncedToCloud: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('RideRequest', rideRequestSchema);
