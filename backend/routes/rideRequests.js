const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  createRideRequest,
  getIncomingRequests,
  getRequestStatus,
  respondToRequest,
} = require('../controllers/rideRequestController');

const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return next();

  try {
    const token = authHeader.split(' ')[1];
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch {
    return res.status(401).json({ message: 'Not authorized, invalid token' });
  }
};

router.post('/', optionalAuth, createRideRequest);
router.get('/incoming', protect, getIncomingRequests);
router.get('/:id/status', getRequestStatus);
router.patch('/:id/respond', protect, respondToRequest);

module.exports = router;
