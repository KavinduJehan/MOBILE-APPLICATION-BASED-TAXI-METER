const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { getReceiptByTripId } = require('../controllers/receiptController');

router.get('/trip/:tripId', protect, getReceiptByTripId);

module.exports = router;
