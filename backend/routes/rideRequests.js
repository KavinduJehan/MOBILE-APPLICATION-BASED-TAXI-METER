const express = require('express');
const router = express.Router();
const { protect, requireRole } = require('../middleware/auth');
const {
  createRideRequest,
  getIncomingRequests,
  getRequestStatus,
  respondToRequest,
} = require('../controllers/rideRequestController');

router.post('/', protect, requireRole('customer'), createRideRequest);
router.get('/incoming', protect, getIncomingRequests);
router.get('/:id/status', getRequestStatus);
router.patch('/:id/respond', protect, respondToRequest);

module.exports = router;
