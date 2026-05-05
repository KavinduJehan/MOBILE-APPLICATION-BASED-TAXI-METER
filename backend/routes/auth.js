const express = require('express');
const router = express.Router();
const { register, login, phoneLogin } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.post('/phone-login', phoneLogin);  // OTP flow: Flutter sends Firebase ID token

module.exports = router;
