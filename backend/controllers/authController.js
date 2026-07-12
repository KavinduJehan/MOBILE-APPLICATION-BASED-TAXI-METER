const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const Driver = require('../models/Driver');
const SystemConfig = require('../models/SystemConfig');

const signToken = (payload) =>
  jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

const loadSystemConfig = async () => {
  let config = await SystemConfig.findOne();
  if (!config) {
    config = await SystemConfig.create({});
  }
  return config;
};

const register = async (req, res) => {
  const { name, email, phone, password, licenseNumber, vehicleNumber, area } = req.body;
  if (!name || !email || !phone || !password || !licenseNumber || !vehicleNumber) {
    return res.status(400).json({ message: 'All fields are required' });
  }

  try {
    const config = await loadSystemConfig();
    if (!config.registrationOpen) {
      return res.status(403).json({ message: 'Driver registration is currently closed.' });
    }

    const exists = await Driver.findOne({ $or: [{ email }, { licenseNumber }] });
    if (exists) return res.status(409).json({ message: 'Driver already registered' });

    const driver = await Driver.create({ name, email, phone, password, licenseNumber, vehicleNumber, area, qrToken: uuidv4() });
    const token = signToken({ id: driver._id, role: driver.role });
    res.status(201).json({ token, driver: { id: driver._id, name, email, role: driver.role } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ message: 'Email and password required' });

  try {
    const driver = await Driver.findOne({ email });
    if (!driver || !(await driver.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    const token = signToken({ id: driver._id, role: driver.role });
    res.json({ token, driver: { id: driver._id, name: driver.name, email, role: driver.role } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { register, login };

// POST /api/auth/phone-login
// Called by Flutter after Firebase OTP verification succeeds.
// Flutter sends the Firebase ID token; we verify it, extract the phone number,
// then find or create a Driver and return our own JWT.
const phoneLogin = async (req, res) => {
  const { idToken, name, licenseNumber, vehicleNumber, area } = req.body;
  if (!idToken) return res.status(400).json({ message: 'idToken is required' });

  let admin;
  try {
    admin = require('../config/firebase');
  } catch {
    return res.status(500).json({ message: 'Firebase not configured on this server' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const phoneNumber = decoded.phone_number;

    if (!phoneNumber) {
      return res.status(400).json({ message: 'Token does not contain a phone number. Ensure Firebase phone auth was used.' });
    }

    let driver = await Driver.findOne({ phone: phoneNumber });

    if (!driver) {
      // First time — registration details required
      const config = await loadSystemConfig();
      if (!config.registrationOpen) {
        return res.status(403).json({ message: 'Driver registration is currently closed.' });
      }

      if (!name || !licenseNumber || !vehicleNumber) {
        return res.status(404).json({
          message: 'Driver not registered. Provide name, licenseNumber, and vehicleNumber to create an account.',
        });
      }

      const licenseExists = await Driver.findOne({ licenseNumber });
      if (licenseExists) {
        return res.status(409).json({ message: 'License number already registered to another account' });
      }

      driver = await Driver.create({
        name,
        phone: phoneNumber,
        licenseNumber,
        vehicleNumber,
        area: area || '',
        qrToken: uuidv4(),
        // no email, no password — OTP-only driver
      });
    }

    const token = signToken({ id: driver._id, role: driver.role });
    res.json({
      token,
      driver: { id: driver._id, name: driver.name, phone: phoneNumber, role: driver.role },
    });
  } catch (err) {
    if (err.code === 'auth/id-token-expired') {
      return res.status(401).json({ message: 'OTP session expired. Please verify again.' });
    }
    if (err.code?.startsWith('auth/')) {
      return res.status(401).json({ message: 'Invalid Firebase token' });
    }
    res.status(500).json({ message: err.message });
  }
};

module.exports = { register, login, phoneLogin };
