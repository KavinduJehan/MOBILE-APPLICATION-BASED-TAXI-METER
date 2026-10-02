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
const allowedProfileImageHeaders = new Set([
  'data:image/jpeg;base64',
  'data:image/png;base64',
  'data:image/webp;base64',
]);
const maxProfileImageBytes = 750 * 1024;

const hasExpectedImageSignature = (header, bytes) => {
  if (header === 'data:image/jpeg;base64') {
    return bytes.length >= 3 &&
      bytes[0] === 0xff &&
      bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  if (header === 'data:image/png;base64') {
    const pngSignature = '89504e470d0a1a0a';
    return bytes.length >= 8 &&
      bytes.subarray(0, 8).toString('hex') === pngSignature;
  }
  return bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP';
};

const validateProfileImage = (value) => {
  if (value === '') return { valid: true, value: '' };
  if (typeof value !== 'string') {
    return { valid: false, message: 'Profile image must be an image data URL' };
  }
  const separator = value.indexOf(',');
  const header = value.slice(0, separator);
  const payload = value.slice(separator + 1);
  if (
    separator < 0 ||
    !allowedProfileImageHeaders.has(header) ||
    !payload ||
    payload.length % 4 !== 0
  ) {
    return {
      valid: false,
      message: 'Only valid JPEG, PNG, or WebP profile images are allowed',
    };
  }
  const bytes = Buffer.from(payload, 'base64');
  if (
    bytes.length === 0 ||
    bytes.length > maxProfileImageBytes ||
    bytes.toString('base64') !== payload ||
    !hasExpectedImageSignature(header, bytes)
  ) {
    return {
      valid: false,
      message: 'Profile image must be valid and smaller than 750 KB',
    };
  }
  return { valid: true, value };
};
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

  if (!firstName || !lastName || !email || !phone) {
    return res.status(400).json({
      message: 'firstName, lastName, email, and phone are required',
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

// PATCH /api/customers/profile
const updateProfile = async (req, res) => {
  const name = String(req.body.name || '').trim();
  const email = normalizeEmail(req.body.email);
  const phone = normalizePhone(req.body.phone);
  const birthday = String(req.body.birthday || '').trim();
  const gender = String(req.body.gender || '').trim();
  const imageValidation = validateProfileImage(req.body.profileImage ?? '');

  if (!name || name.length > 120) {
    return res.status(400).json({ message: 'Valid name is required' });
  }
  if (!isValidEmail(email)) {
    return res.status(400).json({ message: 'Valid email is required' });
  }
  if (!isValidSriLankanPhone(phone)) {
    return res
      .status(400)
      .json({ message: 'Valid Sri Lankan phone number is required' });
  }
  if (birthday.length > 30 || gender.length > 30) {
    return res.status(400).json({ message: 'Profile details are too long' });
  }
  if (!imageValidation.valid) {
    return res.status(400).json({ message: imageValidation.message });
  }

  try {
    const duplicate = await Customer.findOne({
      _id: { $ne: req.user.id },
      $or: [{ email }, { phone }],
    });
    if (duplicate) {
      return res.status(409).json({
        message:
          duplicate.email === email
            ? 'Email is already registered'
            : 'Phone number is already registered',
      });
    }

    const customer = await Customer.findById(req.user.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    customer.name = name;
    customer.email = email;
    customer.phone = phone;
    customer.birthday = birthday;
    customer.gender = gender;
    customer.profileImage = imageValidation.value;
    await customer.save();

    return res.json({ customer: publicCustomer(customer) });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

// GET /api/customers/saved-places
const getSavedPlaces = async (req, res) => {
  try {
    const customer = await Customer.findById(req.user.id).select('savedPlaces');
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    return res.json({ savedPlaces: customer.savedPlaces || [] });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

// PUT /api/customers/saved-places
const updateSavedPlaces = async (req, res) => {
  const { savedPlaces } = req.body;
  if (!Array.isArray(savedPlaces)) {
    return res.status(400).json({ message: 'savedPlaces must be an array' });
  }
  if (savedPlaces.length > 20) {
    return res.status(400).json({ message: 'A maximum of 20 saved places is allowed' });
  }

  const normalizedPlaces = [];
  for (const place of savedPlaces) {
    if (!place || typeof place !== 'object' || Array.isArray(place)) {
      return res.status(400).json({ message: 'Each saved place must be an object' });
    }

    const label = String(place.label || '').trim();
    const address = String(place.address || '').trim();
    const lat = place.lat == null ? null : Number(place.lat);
    const lng = place.lng == null ? null : Number(place.lng);

    if (!label || !address) {
      return res.status(400).json({ message: 'Each saved place requires a label and address' });
    }
    if (label.length > 50 || address.length > 500) {
      return res.status(400).json({ message: 'Saved place label or address is too long' });
    }
    if (lat !== null && (!Number.isFinite(lat) || lat < -90 || lat > 90)) {
      return res.status(400).json({ message: 'Saved place latitude must be between -90 and 90' });
    }
    if (lng !== null && (!Number.isFinite(lng) || lng < -180 || lng > 180)) {
      return res.status(400).json({ message: 'Saved place longitude must be between -180 and 180' });
    }

    normalizedPlaces.push({ label, address, lat, lng });
  }

  try {
    const customer = await Customer.findById(req.user.id);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    customer.savedPlaces = normalizedPlaces;
    await customer.save();
    return res.json({ savedPlaces: customer.savedPlaces });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

// POST /api/customers/phone-login
// Called by Flutter customer app after Firebase OTP verification succeeds.
// Flutter sends the Firebase ID token; we verify it, extract the phone number,
// then find or create the Customer and return session tokens.
const phoneLogin = async (req, res) => {
  const { idToken, firstName, lastName, email } = req.body;
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
      return res.status(400).json({
        message: 'Token does not contain a phone number. Ensure Firebase phone auth was used.',
      });
    }

    // Convert E.164 (+94...) to local 0-prefixed phone number if applicable
    const localPhone = phoneNumber.startsWith('+94')
      ? '0' + phoneNumber.slice(3)
      : phoneNumber;

    let customer = await Customer.findOne({
      $or: [{ phone: phoneNumber }, { phone: localPhone }],
    });

    if (!customer) {
      const cFirst = String(firstName || 'Customer').trim();
      const cLast = String(lastName || '').trim();
      const cName = `${cFirst} ${cLast}`.trim();
      const cEmail =
        normalizeEmail(email) ||
        `${localPhone.replace(/[^0-9]/g, '')}@customer.taximeter.local`;

      customer = await Customer.create({
        firstName: cFirst,
        lastName: cLast,
        name: cName,
        email: cEmail,
        phone: localPhone,
      });
    }

    res.json(issueSession(customer));
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

module.exports = {
  register,
  login,
  requestOtp,
  verifyOtp,
  phoneLogin,
  refreshToken,
  updateProfile,
  getSavedPlaces,
  updateSavedPlaces,
};

