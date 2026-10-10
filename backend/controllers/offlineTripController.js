const Trip = require('../models/Trip');
const Receipt = require('../models/Receipt');
const Driver = require('../models/Driver');
const Customer = require('../models/Customer');
const { issueIdentity } = require('../services/offlineIdentity');
const { validateOfflineSnapshot } = require('../services/offlineTripValidation');

const getOfflineIdentity = async (req, res) => {
  if (req.user.role !== 'customer') return res.status(403).json({ message: 'Customer account required' });
  return res.json({ identity: issueIdentity(req.user.id) });
};

// Separate protocol for the offline section; existing online endpoints are unchanged.
const syncOfflineHandshakeTrips = async (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ message: 'Driver account required' });
  const items = req.body.trips;
  if (!Array.isArray(items) || !items.length || items.length > 100) {
    return res.status(400).json({ message: 'Send between 1 and 100 offline trips' });
  }
  try {
    const driver = await Driver.findById(req.user.id);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    let validated;
    try { validated = items.map((item) => validateOfflineSnapshot(item, driver)); }
    catch (e) { return res.status(400).json({ message: e.message }); }
    const idMap = {};
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const value = validated[i];
      const existingReceipt = await Receipt.findOne({ receiptNumber: value.receiptNumber });
      if (existingReceipt && String(existingReceipt.driver) !== req.user.id) {
        return res.status(409).json({ message: 'Offline receipt already belongs to another driver' });
      }
      if (value.customer && !await Customer.exists({ _id: value.customer })) value.customer = null;
      const filter = { driver: req.user.id, offlineLocalId: item.localId };
      let trip;
      try {
        trip = await Trip.findOneAndUpdate(filter, { $setOnInsert: {
          ...filter, customer: value.customer,
          customerName: item.customerName || 'Offline Passenger',
          startLocation: item.startAddress || 'Street Pickup', endLocation: item.endAddress || 'Meter Destination',
          distanceKm: value.distanceKm, ratePerKm: value.ratePerKm, totalFare: value.totalFare,
          startTime: value.startTime, pickedUpAt: value.startTime, endTime: value.endTime,
          status: 'completed', syncedToCloud: true,
        } }, { upsert: true, new: true, runValidators: true });
      } catch (e) {
        // Another request may have inserted the same ID concurrently.
        if (e.code !== 11000) throw e;
        trip = await Trip.findOne(filter);
        if (!trip) throw e;
      }
      // Recover a receipt after a previous request failed between the two writes.
      const receipt = await Receipt.findOneAndUpdate({ receiptNumber: value.receiptNumber }, { $setOnInsert: {
        trip: trip._id, driver: req.user.id, receiptNumber: value.receiptNumber,
        customerName: trip.customerName, startLocation: trip.startLocation, endLocation: trip.endLocation,
        distanceKm: trip.distanceKm, ratePerKm: trip.ratePerKm, totalFare: trip.totalFare,
        baseFare: trip.totalFare, durationMinutes: (trip.endTime - trip.startTime) / 60000,
        issuedAt: trip.endTime,
      } }, { upsert: true, new: true, runValidators: true });
      if (String(receipt.driver) !== req.user.id || String(receipt.trip) !== String(trip._id)) {
        return res.status(409).json({ message: 'Offline receipt identity mismatch' });
      }
      idMap[item.localId] = String(trip._id);
    }
    return res.json({ success: true, syncedCount: Object.keys(idMap).length, idMap });
  } catch (err) { return res.status(500).json({ message: err.message }); }
};

module.exports = { getOfflineIdentity, syncOfflineHandshakeTrips };
