const express = require('express');
const router = express.Router();
const { protect, requireRole } = require('../middleware/auth');
const { listDrivers, setDriverVerification, getAllTrips, getStats } = require('../controllers/adminController');
const { getConfig, updateConfig } = require('../controllers/systemConfigController');

// All admin routes require a valid JWT AND the 'regulator' role
router.use(protect, requireRole('regulator'));

router.get('/drivers', listDrivers);
router.patch('/drivers/:id/verify', setDriverVerification);
router.get('/trips', getAllTrips);
router.get('/stats', getStats);
router.get('/config', getConfig);
router.patch('/config', updateConfig);

module.exports = router;
