const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const savedPlaceSchema = new mongoose.Schema(
  {
    label: { type: String, required: true, trim: true, maxlength: 50 },
    address: { type: String, required: true, trim: true, maxlength: 500 },
    lat: { type: Number, default: null, min: -90, max: 90 },
    lng: { type: Number, default: null, min: -180, max: 180 },
  },
  { _id: false }
);

const customerSchema = new mongoose.Schema(
  {
    firstName: { type: String, trim: true },
    lastName: { type: String, trim: true },
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      unique: true,
      sparse: true,
      lowercase: true,
      trim: true,
    },
    phone: { type: String, required: true, unique: true, trim: true },
    password: { type: String },
    otp: { type: String },
    otpDebug: { type: String },
    otpExpiry: { type: Date },
    savedPlaces: { type: [savedPlaceSchema], default: [] },
  },
  { timestamps: true }
);

customerSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

customerSchema.methods.comparePassword = async function (candidatePassword) {
  if (!this.password) return false;
  return bcrypt.compare(candidatePassword, this.password);
};

customerSchema.methods.compareOtp = async function (candidateOtp) {
  if (!this.otp) return false;
  return bcrypt.compare(candidateOtp, this.otp);
};

module.exports = mongoose.model('Customer', customerSchema);
