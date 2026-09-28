const express = require('express');
const router = express.Router();
const { register, login, phoneLogin, forgotPassword, resetPassword } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.post('/phone-login', phoneLogin);  // OTP flow: Flutter sends Firebase ID token
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);

module.exports = router;
