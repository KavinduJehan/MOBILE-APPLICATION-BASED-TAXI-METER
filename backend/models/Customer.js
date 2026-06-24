const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const customerSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, unique: true },
    otp: { type: String },        // bcrypt-hashed OTP — cleared after use
    otpExpiry: { type: Date },
  },
  { timestamps: true }
);

customerSchema.methods.compareOtp = async function (candidateOtp) {
  if (!this.otp) return false;
  return bcrypt.compare(candidateOtp, this.otp);
};

module.exports = mongoose.model('Customer', customerSchema);
