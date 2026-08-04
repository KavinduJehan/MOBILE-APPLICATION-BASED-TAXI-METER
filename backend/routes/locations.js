const express = require('express');
const { protect, requireRole } = require('../middleware/auth');
const {
  autocompletePlaces,
  getPlaceDetails,
  reverseGeocode,
  getDrivingRoute,
} = require('../controllers/locationController');

const router = express.Router();

router.get('/autocomplete', protect, requireRole('customer'), autocompletePlaces);
router.get('/reverse', protect, requireRole('customer'), reverseGeocode);
router.get('/details/:placeId', protect, requireRole('customer'), getPlaceDetails);
router.post('/route', protect, requireRole('customer'), getDrivingRoute);

module.exports = router;
