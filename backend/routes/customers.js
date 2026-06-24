const express = require('express');
const router = express.Router();
const { register, requestOtp, verifyOtp } = require('../controllers/customerController');

router.post('/register', register);       // first-time signup
router.post('/request-otp', requestOtp); // send OTP to existing account
router.post('/verify-otp', verifyOtp);   // validate OTP → return JWT

module.exports = router;
