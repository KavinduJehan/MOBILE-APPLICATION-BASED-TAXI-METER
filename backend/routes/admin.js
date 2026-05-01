const express = require('express');
const router = express.Router();
const { protect, requireRole } = require('../middleware/auth');
const { listDrivers, setDriverVerification, getAllTrips } = require('../controllers/adminController');

// All admin routes require a valid JWT AND the 'regulator' role
router.use(protect, requireRole('regulator'));

router.get('/drivers', listDrivers);
router.patch('/drivers/:id/verify', setDriverVerification);
router.get('/trips', getAllTrips);

module.exports = router;
