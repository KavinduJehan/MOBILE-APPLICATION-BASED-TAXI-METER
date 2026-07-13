const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  register,
  login,
  requestOtp,
  verifyOtp,
  refreshToken,
  updateProfile,
  getSavedPlaces,
  updateSavedPlaces,
} = require('../controllers/customerController');

router.post('/register', register);
router.post('/login', login);
router.post('/request-otp', requestOtp);
router.post('/verify-otp', verifyOtp);
router.post('/refresh-token', refreshToken);
router.patch('/profile', protect, updateProfile);
router.get('/saved-places', protect, getSavedPlaces);
router.patch('/saved-places', protect, updateSavedPlaces);

module.exports = router;
