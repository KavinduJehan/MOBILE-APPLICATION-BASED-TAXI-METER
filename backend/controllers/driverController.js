const QRCode = require('qrcode');
const Driver = require('../models/Driver');

const getDriverProfile = async (req, res) => {
  try {
    const driver = await Driver.findById(req.user.id).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Generates a QR code that encodes the driver's public profile URL
const updateQRCode = async (req, res) => {
  try {
    const driver = await Driver.findById(req.user.id);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    const qrPayload = JSON.stringify({
      token: driver.qrToken,
      name: driver.name,
      licenseNumber: driver.licenseNumber,
      vehicleNumber: driver.vehicleNumber,
      area: driver.area,
      ratePerKm: driver.ratePerKm,
    });

    const qrCode = await QRCode.toDataURL(qrPayload);
    driver.qrCode = qrCode;
    await driver.save();

    res.json({ qrCode });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Returns drivers in a given area
const getNearbyDrivers = async (req, res) => {
  const { area } = req.query;
  try {
    const filter = area ? { area, isVerified: true } : { isVerified: true };
    const drivers = await Driver.find(filter).select('name vehicleNumber ratePerKm area qrCode');
    res.json(drivers);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Looks up a driver by the opaque qrToken embedded in their QR code
const getDriverByQR = async (req, res) => {
  const { qrToken } = req.params;
  try {
    const driver = await Driver.findOne({ qrToken }).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getDriverProfile, updateQRCode, getNearbyDrivers, getDriverByQR };
