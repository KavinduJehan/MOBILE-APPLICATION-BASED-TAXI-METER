const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const driverSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // Optional for OTP-only drivers — sparse so null values don't conflict on the unique index
    email: { type: String, unique: true, sparse: true, lowercase: true },
    phone: { type: String, required: true, unique: true },
    // Optional for OTP-only drivers
    password: { type: String },
    licenseNumber: { type: String, required: true, unique: true },
    vehicleNumber: { type: String, required: true },
    role: { type: String, enum: ['driver', 'regulator'], default: 'driver' },
    isVerified: { type: Boolean, default: false },
    qrToken: { type: String, unique: true, sparse: true }, // opaque lookup token embedded in QR
    qrCode: { type: String },                 // Base64 or URL to QR image
    ratePerKm: { type: Number, default: 0 },  // Per-km rate in LKR
    area: { type: String, default: '' },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: undefined,
      },
      coordinates: {
        type: [Number],
        default: undefined,
      },
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      updatedAt: { type: Date, default: null },
    },
    resetPasswordCode: { type: String, default: null },
    resetPasswordDebug: { type: String, default: null },
    resetPasswordExpires: { type: Date, default: null },
  },
  { timestamps: true }
);

driverSchema.index(
  { location: '2dsphere' },
  { partialFilterExpression: { 'location.coordinates': { $exists: true } } }
);

driverSchema.pre('save', async function (next) {
  if (!this.password || !this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

driverSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

driverSchema.methods.compareResetCode = async function (candidateCode) {
  if (!this.resetPasswordCode) return false;
  return bcrypt.compare(candidateCode, this.resetPasswordCode);
};

module.exports = mongoose.model('Driver', driverSchema);

