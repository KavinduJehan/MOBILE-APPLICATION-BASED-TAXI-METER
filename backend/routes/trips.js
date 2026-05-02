const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { createTrip, endTrip, getMyTrips, getIncome } = require('../controllers/tripController');

router.post('/', protect, createTrip);
router.patch('/:id/end', protect, endTrip);
router.get('/my', protect, getMyTrips);
router.get('/income', protect, getIncome);

module.exports = router;
