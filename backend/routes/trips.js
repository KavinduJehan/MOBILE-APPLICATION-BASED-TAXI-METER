const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { createTrip, endTrip, getMyTrips } = require('../controllers/tripController');

router.post('/', protect, createTrip);
router.patch('/:id/end', protect, endTrip);
router.get('/my', protect, getMyTrips);

module.exports = router;
