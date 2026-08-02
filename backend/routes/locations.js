const express = require('express');
const { protect, requireRole } = require('../middleware/auth');
const {
  autocompletePlaces,
  getPlaceDetails,
  reverseGeocode,
} = require('../controllers/locationController');

const router = express.Router();

router.get('/autocomplete', protect, requireRole('customer'), autocompletePlaces);
router.get('/reverse', protect, requireRole('customer'), reverseGeocode);
router.get('/details/:placeId', protect, requireRole('customer'), getPlaceDetails);

module.exports = router;
