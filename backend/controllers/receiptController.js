const Receipt = require('../models/Receipt');
const Trip = require('../models/Trip');

const canAccessTrip = (trip, req) => {
  const userId = req.user.id;
  const driverId = trip.driver?._id || trip.driver;
  const customerId = trip.customer?._id || trip.customer;
  return (
    driverId?.toString() === userId ||
    customerId?.toString() === userId
  );
};

const getReceiptByTripId = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.tripId);
    if (!trip) return res.status(404).json({ message: 'Trip not found' });
    if (!canAccessTrip(trip, req)) return res.status(403).json({ message: 'Forbidden' });

    const receipt = await Receipt.findOne({ trip: trip._id })
      .populate('trip', 'startLocation endLocation startTime endTime status')
      .populate('driver', 'name vehicleNumber vehicleType phone');

    if (!receipt) return res.status(404).json({ message: 'Receipt not found' });

    res.json(receipt);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getReceiptByTripId };
