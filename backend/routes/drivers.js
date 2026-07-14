const express = require('express');
const router = express.Router();
const { protect, requireRole } = require('../middleware/auth');
const {
  getDriverProfile,
  updateQRCode,
  getNearbyDrivers,
  getDriverByQR,
  updateLocation,
} = require('../controllers/driverController');

router.get('/profile', protect, getDriverProfile);
router.post('/generate-qr', protect, updateQRCode);
router.patch('/location', protect, requireRole('driver'), updateLocation);
router.get('/nearby', getNearbyDrivers);
router.get('/qr/:qrToken', getDriverByQR);

module.exports = router;


