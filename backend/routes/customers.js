const express = require('express');
const router = express.Router();
const {
  register,
  login,
  requestOtp,
  verifyOtp,
  refreshToken,
} = require('../controllers/customerController');

router.post('/register', register);
router.post('/login', login);
router.post('/request-otp', requestOtp);
router.post('/verify-otp', verifyOtp);
router.post('/refresh-token', refreshToken);

module.exports = router;
