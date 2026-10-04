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

    // The rate the customer was quoted when the request was made. This is the
    // rate charged unless a negotiation agrees a lower one.
    driverRatePerKm: { type: Number, required: true },

    // AUTO mode: the surge breakdown behind the quoted rate (null otherwise)
    surgeBreakdown: { type: mongoose.Schema.Types.Mixed, default: null },

    // Customer's negotiated rate — null means no negotiation (accept driver's rate)
    suggestedRatePerKm: { type: Number, default: null },

    // Driver's counter-offer to the customer's suggested rate (between the two rates)
    counterRatePerKm: { type: Number, default: null },

    // Where the fare negotiation stands while the request is pending:
    //   none             – no negotiation, driver's rate applies
    //   customer_offered – customer suggested a lower rate, waiting for the driver
    //   driver_countered – driver sent a counter-offer, waiting for the customer
    //   agreed           – one side accepted the other's offer
    //   declined         – the negotiation ended without agreement
    negotiationStatus: {
      type: String,
      enum: ['none', 'customer_offered', 'driver_countered', 'agreed', 'declined'],
      default: 'none',
    },

    // Agreed rate — set when the ride is accepted (driver's rate, the customer's
    // suggested rate, or the driver's counter-offer the customer agreed to)
    agreedRatePerKm: { type: Number, default: null },

    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'expired'],
      default: 'pending',
    },

    // Keeps the request locked while the customer is waiting or riding.
    // A partial unique index below makes the one-active-ride rule atomic.
    isActive: { type: Boolean, default: true },

    // Populated when driver accepts — links to the created Trip
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', default: null },

    // Reserved for future offline sync
    syncedToCloud: { type: Boolean, default: true },
  },
  { timestamps: true }
);

rideRequestSchema.index(
  { customer: 1 },
  {
    unique: true,
    partialFilterExpression: {
      isActive: true,
      customer: { $type: 'objectId' },
    },
  }
);

module.exports = mongoose.model('RideRequest', rideRequestSchema);
