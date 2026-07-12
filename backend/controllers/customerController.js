const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Customer = require('../models/customerModel');

const normalizeSavedPlaces = (places = []) => {
  if (!Array.isArray(places)) return [];
  return places
    .map((place) => ({
      label: String(place.label || '').trim(),
      address: String(place.address || '').trim(),
      lat: place.lat == null ? null : Number(place.lat),
      lng: place.lng == null ? null : Number(place.lng),
    }))
    .filter((place) => place.label && place.address)
    .map((place) => ({
      label: place.label,
      address: place.address,
      lat: Number.isFinite(place.lat) ? place.lat : null,
      lng: Number.isFinite(place.lng) ? place.lng : null,
    }));
};

const getSavedPlaces = async (req, res) => {
  try {
    const customer = await Customer.findById(req.user.id).select('savedPlaces');
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    res.json({ savedPlaces: customer.savedPlaces || [] });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateSavedPlaces = async (req, res) => {
  const savedPlaces = normalizeSavedPlaces(req.body.savedPlaces);
  try {
    const customer = await Customer.findByIdAndUpdate(
      req.user.id,
      { savedPlaces },
      { new: true, runValidators: true }
    ).select('savedPlaces');
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    res.json({ savedPlaces: customer.savedPlaces || [] });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
// POST /api/customers/register
// First-time signup — name + phone only
const register = async (req, res) => {
  const { name, phone } = req.body;
  if (!name || !phone) {
    return res.status(400).json({ message: 'name and phone are required' });
  }

  try {
    const existing = await Customer.findOne({ phone });
    if (existing) {
      return res.status(409).json({ message: 'Phone number already registered' });
    }

    const customer = await Customer.create({ name, phone });
    res.status(201).json({
      id: customer._id,
      name: customer.name,
      phone: customer.phone,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/request-otp
// Generates a 6-digit OTP and logs it to console (replace with SMS in production)
const requestOtp = async (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ message: 'phone is required' });

  try {
    const customer = await Customer.findOne({ phone });
    if (!customer) {
      return res.status(404).json({ message: 'No account found for this phone number' });
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const hashedOtp = await bcrypt.hash(otp, 10);

    customer.otp = hashedOtp;
    customer.otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // valid for 10 minutes
    await customer.save();

    // TODO: replace with real SMS gateway before production
    console.log(`[OTP] Phone: ${phone}  OTP: ${otp}`);

    res.json({ message: 'OTP sent' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/verify-otp
// Validates OTP and returns a JWT (30-day session)
const verifyOtp = async (req, res) => {
  const { phone, otp } = req.body;
  if (!phone || !otp) {
    return res.status(400).json({ message: 'phone and otp are required' });
  }

  try {
    const customer = await Customer.findOne({ phone });
    if (!customer) {
      return res.status(404).json({ message: 'No account found for this phone number' });
    }

    if (!customer.otpExpiry || customer.otpExpiry < new Date()) {
      return res.status(400).json({ message: 'OTP has expired, request a new one' });
    }

    const valid = await customer.compareOtp(otp);
    if (!valid) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    // Clear OTP after successful use
    customer.otp = undefined;
    customer.otpExpiry = undefined;
    await customer.save();

    const token = jwt.sign(
      { id: customer._id, name: customer.name, phone: customer.phone, role: 'customer' },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      customer: { id: customer._id, name: customer.name, phone: customer.phone },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  register,
  requestOtp,
  verifyOtp,
  getSavedPlaces,
  updateSavedPlaces,
};

