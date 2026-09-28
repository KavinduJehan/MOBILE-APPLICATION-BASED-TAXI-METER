const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { updateRate, getAreaRates, getAutoRate } = require('../controllers/rateController');

router.patch('/my-rate', protect, updateRate);
router.get('/area', getAreaRates);        // ?area=Colombo  – manual mode average
router.get('/auto', getAutoRate);         // ?area=Colombo  – algorithm-computed rate

module.exports = router;
