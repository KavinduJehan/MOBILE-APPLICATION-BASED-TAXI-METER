const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  createRideRequest,
  getIncomingRequests,
  getRequestStatus,
  respondToRequest,
} = require('../controllers/rideRequestController');

router.post('/', createRideRequest);                         // customer — no auth
router.get('/incoming', protect, getIncomingRequests);       // driver — auth required
router.get('/:id/status', getRequestStatus);                 // customer polls — no auth
router.patch('/:id/respond', protect, respondToRequest);     // driver — auth required

module.exports = router;
