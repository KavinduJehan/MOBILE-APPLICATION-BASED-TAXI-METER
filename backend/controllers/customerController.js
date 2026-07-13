const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Customer = require('../models/Customer');

const publicCustomer = (customer) => ({
  id: customer._id,
  firstName: customer.firstName || customer.name?.split(' ')[0] || '',
  lastName: customer.lastName || '',
  name: customer.name,
  email: customer.email || '',
  phone: customer.phone,
  birthday: customer.birthday || '',
  gender: customer.gender || '',
  profileImage: customer.profileImage || '',
  savedPlaces: customer.savedPlaces || [],
});

const signAccessToken = (customer) =>
  jwt.sign(
    {
      id: customer._id,
      name: customer.name,
      phone: customer.phone,
      role: 'customer',
    },
    process.env.JWT_SECRET,
    { expiresIn: '30d' }
  );

const signRefreshToken = (customer) =>
  jwt.sign(
    { id: customer._id, type: 'refresh', role: 'customer' },
    process.env.JWT_SECRET,
    { expiresIn: '60d' }
  );

const isProduction = () => process.env.NODE_ENV === 'production';
const normalizePhone = (phone) => String(phone || '').trim();
const normalizeEmail = (email) => String(email || '').trim().toLowerCase();
const isValidEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
const isValidSriLankanPhone = (phone) => /^0[1-9]\d{8}$/.test(phone);

const issueSession = (customer) => {
  const token = signAccessToken(customer);
  return {
    token,
    accessToken: token,
    refreshToken: signRefreshToken(customer),
    customer: publicCustomer(customer),
  };
};

// POST /api/customers/register
const register = async (req, res) => {
  const firstName = String(req.body.firstName || '').trim();
  const lastName = String(req.body.lastName || '').trim();
  const email = normalizeEmail(req.body.email);
  const phone = normalizePhone(req.body.phone);
  const password = String(req.body.password || '');

  if (!firstName || !lastName || !email || !phone || !password) {
    return res.status(400).json({
      message: 'firstName, lastName, email, phone, and password are required',
    });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ message: 'Valid email is required' });
  }
  if (!isValidSriLankanPhone(phone)) {
    return res
      .status(400)
      .json({ message: 'Valid Sri Lankan phone number is required' });
  }
  if (password.length < 6) {
    return res
      .status(400)
      .json({ message: 'Password must be at least 6 characters' });
  }

  try {
    const existing = await Customer.findOne({ $or: [{ phone }, { email }] });
    if (existing) {
      return res.status(409).json({
        message:
          existing.phone === phone
            ? 'Phone number already registered'
            : 'Email already registered',
      });
    }

    const customer = await Customer.create({
      firstName,
      lastName,
      name: `${firstName} ${lastName}`.trim(),
      email,
      phone,
      password,
    });
    res.status(201).json(publicCustomer(customer));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/login
const login = async (req, res) => {
  const identifier = String(req.body.identifier || '').trim();
  const password = String(req.body.password || '');

  if (!identifier || !password) {
    return res
      .status(400)
      .json({ message: 'identifier and password are required' });
  }

  try {
    const customer = await Customer.findOne({
      $or: [{ email: identifier.toLowerCase() }, { phone: identifier }],
    });
    if (!customer || !(await customer.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    res.json(issueSession(customer));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/request-otp
const requestOtp = async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  if (!phone) return res.status(400).json({ message: 'phone is required' });

  try {
    const customer = await Customer.findOne({ phone });
    if (!customer) {
      return res
        .status(404)
        .json({ message: 'No account found for this phone number' });
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const hashedOtp = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    customer.otp = hashedOtp;
    customer.otpDebug = isProduction() ? undefined : otp;
    customer.otpExpiry = expiresAt;
    await customer.save();

    console.log(`[OTP] Phone: ${phone}  OTP: ${otp}`);

    res.json({
      message: 'OTP sent',
      expiresAt,
      ...(!isProduction() ? { devOtp: otp } : {}),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/verify-otp
const verifyOtp = async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  const otp = String(req.body.otp || '').trim();
  if (!phone || !otp) {
    return res.status(400).json({ message: 'phone and otp are required' });
  }

  try {
    const customer = await Customer.findOne({ phone });
    if (!customer) {
      return res
        .status(404)
        .json({ message: 'No account found for this phone number' });
    }

    if (!customer.otpExpiry || customer.otpExpiry < new Date()) {
      return res
        .status(400)
        .json({ message: 'OTP has expired, request a new one' });
    }

    const valid =
      (await customer.compareOtp(otp)) ||
      (!isProduction() && customer.otpDebug === otp);
    if (!valid) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    customer.otp = undefined;
    customer.otpDebug = undefined;
    customer.otpExpiry = undefined;
    await customer.save();

    res.json(issueSession(customer));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const refreshToken = async (req, res) => {
  const { refreshToken: token } = req.body;
  if (!token) {
    return res.status(400).json({ message: 'refreshToken is required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.type !== 'refresh' || decoded.role !== 'customer') {
      return res.status(401).json({ message: 'Invalid refresh token' });
    }

    const customer = await Customer.findById(decoded.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    res.json(issueSession(customer));
  } catch {
    return res.status(401).json({ message: 'Invalid refresh token' });
  }
};

const updateProfile = async (req, res) => {
  const allowed = ['name', 'email', 'phone', 'birthday', 'gender', 'profileImage'];
  const updates = {};

  for (const key of allowed) {
    if (req.body[key] !== undefined) updates[key] = String(req.body[key]).trim();
  }

  if (updates.email) updates.email = normalizeEmail(updates.email);
  if (updates.email && !isValidEmail(updates.email)) {
    return res.status(400).json({ message: 'Valid email is required' });
  }
  if (updates.phone && !isValidSriLankanPhone(updates.phone)) {
    return res
      .status(400)
      .json({ message: 'Valid Sri Lankan phone number is required' });
  }

  try {
    const customer = await Customer.findByIdAndUpdate(req.user.id, updates, {
      new: true,
      runValidators: true,
    });
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    res.json(publicCustomer(customer));
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'Email or phone already in use' });
    }
    res.status(500).json({ message: err.message });
  }
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
  const savedPlaces = Array.isArray(req.body.savedPlaces)
    ? req.body.savedPlaces
    : [];

  const sanitized = savedPlaces
    .map((place) => ({
      label: String(place.label || '').trim(),
      address: String(place.address || '').trim(),
      lat: place.lat === undefined || place.lat === null ? undefined : Number(place.lat),
      lng: place.lng === undefined || place.lng === null ? undefined : Number(place.lng),
    }))
    .filter((place) => place.label && place.address)
    .slice(0, 20);

  try {
    const customer = await Customer.findByIdAndUpdate(
      req.user.id,
      { savedPlaces: sanitized },
      { new: true, runValidators: true }
    ).select('savedPlaces');
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    res.json({ savedPlaces: customer.savedPlaces || [] });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  register,
  login,
  requestOtp,
  verifyOtp,
  refreshToken,
  updateProfile,
  getSavedPlaces,
  updateSavedPlaces,
};
