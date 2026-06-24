const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  createTrip,
  startTrip,
  endTrip,
  getTripDetails,
  getMyTrips,
  getIncome,
} = require('../controllers/tripController');

router.post('/', protect, createTrip);
router.patch('/:id/start', protect, startTrip);
router.patch('/:id/end', protect, endTrip);
router.get('/my', protect, getMyTrips);
router.get('/income', protect, getIncome);
router.get('/:id', protect, getTripDetails);

module.exports = router;
