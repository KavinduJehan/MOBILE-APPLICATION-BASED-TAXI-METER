const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const Driver = require('../models/Driver');

const signToken = (payload) =>
  jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

const register = async (req, res) => {
  const { name, email, phone, password, licenseNumber, vehicleNumber, area } = req.body;
  if (!name || !email || !phone || !password || !licenseNumber || !vehicleNumber) {
    return res.status(400).json({ message: 'All fields are required' });
  }

  try {
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
