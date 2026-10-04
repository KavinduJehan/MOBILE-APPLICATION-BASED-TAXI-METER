const express = require('express');
const router = express.Router();
const { protect, requireRole, requirePasswordChangeComplete } = require('../middleware/auth');
const { changePassword } = require('../controllers/adminAuthController');
const { listDrivers, setDriverVerification, setDriverPricing, getAllTrips, getStats } = require('../controllers/adminController');
const { getConfig, updateConfig } = require('../controllers/systemConfigController');

// A newly seeded admin can change the initial password before using other admin routes.
router.use(protect, requireRole('regulator'));
router.put('/change-password', changePassword);
router.use(requirePasswordChangeComplete);

router.get('/drivers', listDrivers);
router.patch('/drivers/:id/verify', setDriverVerification);
router.patch('/drivers/:id/pricing', setDriverPricing);
router.get('/trips', getAllTrips);
router.get('/stats', getStats);
router.get('/config', getConfig);
router.patch('/config', updateConfig);

module.exports = router;
