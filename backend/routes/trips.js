const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  createTrip,
  startTrip,
  endTrip,
  cancelTrip,
  getTripDetails,
  getMyTrips,
  getIncome,
  syncOfflineTrips,
} = require('../controllers/tripController');

router.post('/', protect, createTrip);
router.post('/sync', protect, syncOfflineTrips);
router.patch('/:id/start', protect, startTrip);
router.patch('/:id/end', protect, endTrip);
router.patch('/:id/cancel', protect, cancelTrip);
router.get('/my', protect, getMyTrips);
router.get('/income', protect, getIncome);
router.get('/:id', protect, getTripDetails);

module.exports = router;
