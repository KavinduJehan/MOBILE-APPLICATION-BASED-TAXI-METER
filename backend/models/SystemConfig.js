const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema(
  {
    // Rate mode: DRIVER = manual, ADMIN = fixed global, AUTO = surge algorithm
    rateMode: { type: String, enum: ['ADMIN', 'DRIVER', 'AUTO'], default: 'ADMIN' },
    registrationOpen: { type: Boolean, default: true },
    negotiationEnabled: { type: Boolean, default: true },
    onlineSearchEnabled: { type: Boolean, default: true },

    // ── AUTO mode pricing config ─────────────────────────────────────────────
    // Base rate the surge multiplier is applied to (LKR per km)
    autoBaseRate: { type: Number, default: 100 },
    // Multiplier is clamped to this range (Uber-style: 1.0 – 2.5)
    autoMinMultiplier: { type: Number, default: 1.0 },
    autoMaxMultiplier: { type: Number, default: 2.5 },
    // Per-area tier multipliers. Keys are area names, values are factors (≥ 1.0).
    // Standard Sri Lankan tier approach:
    //   Tier A (High demand): Colombo, Kandy, Galle → 1.15
    //   Tier B (Moderate):    Negombo, Kurunegala, Ratnapura → 1.05
    //   Tier C (Low/rural):   all others → 1.0
    autoAreaFactors: {
      type: Map,
      of: Number,
      default: {
        Colombo: 1.15,
        Kandy: 1.15,
        Galle: 1.15,
        Negombo: 1.05,
        Kurunegala: 1.05,
        Ratnapura: 1.05,
      },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SystemConfig', systemConfigSchema);