const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const driverSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true },
    phone: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    licenseNumber: { type: String, required: true, unique: true },
    vehicleNumber: { type: String, required: true },
    role: { type: String, enum: ['driver', 'regulator'], default: 'driver' },
    isVerified: { type: Boolean, default: false },
    qrToken: { type: String, unique: true, sparse: true }, // opaque lookup token embedded in QR
    qrCode: { type: String },                 // Base64 or URL to QR image
    ratePerKm: { type: Number, default: 0 },  // Per-km rate in LKR
    area: { type: String, default: '' },
    location: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      updatedAt: { type: Date, default: null },
    },
  },
  { timestamps: true }
);

driverSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

driverSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('Driver', driverSchema);
