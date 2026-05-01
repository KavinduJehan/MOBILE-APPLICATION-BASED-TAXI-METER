const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { updateRate, getAreaRates } = require('../controllers/rateController');

router.patch('/my-rate', protect, updateRate);
router.get('/area', getAreaRates);   // ?area=Colombo

module.exports = router;
