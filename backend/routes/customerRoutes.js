const express = require('express');
const router = express.Router();
const {
  register,
  requestOtp,
  verifyOtp,
  phoneLogin,
  updateProfile,
  getSavedPlaces,
  updateSavedPlaces,
} = require('../controllers/customerController');
const { protect, requireRole } = require('../middleware/auth');

router.post('/register', register);         // first-time signup
router.post('/request-otp', requestOtp);   // send OTP to existing account
router.post('/verify-otp', verifyOtp);     // validate OTP
router.post('/phone-login', phoneLogin);   // Firebase phone OTP authentication
router.patch('/profile', protect, requireRole('customer'), updateProfile);
router.get('/saved-places', protect, requireRole('customer'), getSavedPlaces);
router.put('/saved-places', protect, requireRole('customer'), updateSavedPlaces);

module.exports = router;


