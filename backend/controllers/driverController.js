const QRCode = require('qrcode');
const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const SystemConfig = require('../models/SystemConfig');
const { resolveEffectiveRate } = require('../services/effectiveRate');

// Replaces each driver's stored rate with the rate a customer is actually
// charged right now (regulator rate in ADMIN mode, live surge rate in AUTO
// mode), so the price a customer sees is the price the ride request uses.
// The stored value is kept as baseRatePerKm.
const withEffectiveRates = async (drivers, pickup = {}) => {
  const config = await SystemConfig.findOne().lean();
  // In AUTO mode the rate depends on the place, not the driver: price each
  // distinct place once instead of once per driver.
  const autoCache = new Map();

  return Promise.all(drivers.map(async (driver) => {
    const hasPickup = Number.isFinite(pickup.lat) && Number.isFinite(pickup.lng);
    const point = hasPickup
      ? pickup
      : { lat: driver.location?.lat ?? undefined, lng: driver.location?.lng ?? undefined };
    const hasPoint = Number.isFinite(point.lat) && Number.isFinite(point.lng);
    const key = hasPoint ? `${point.lat},${point.lng}` : `area:${driver.area || ''}`;

    let quote;
    try {
      const mode = driver.pricingMode || config?.rateMode || 'ADMIN';
      if (mode === 'AUTO') {
        if (!autoCache.has(key)) {
          autoCache.set(key, resolveEffectiveRate(driver, config, hasPoint ? point : {}));
        }
        quote = await autoCache.get(key);
      } else {
        quote = await resolveEffectiveRate(driver, config, hasPoint ? point : {});
      }
    } catch {
      return driver; // Pricing unavailable: fall back to the stored rate.
    }

    if (!Number.isFinite(quote.rate) || quote.rate <= 0) return driver;
    return {
      ...driver,
      baseRatePerKm: driver.ratePerKm,
      ratePerKm: quote.rate,
      pricingMode: quote.mode,
    };
  }));
};

// PATCH /api/drivers/profile
// Lets a driver update their own editable fields (not password, not verification status)
const updateDriverProfile = async (req, res) => {
  const allowed = ['name', 'email', 'phone', 'vehicleNumber', 'area'];
  const update = {};
  for (const field of allowed) {
    if (req.body[field] !== undefined) {
      update[field] = String(req.body[field]).trim();
    }
  }
  if (Object.keys(update).length === 0) {
    return res.status(400).json({ message: 'No updatable fields provided' });
  }
  try {
    const driver = await Driver.findByIdAndUpdate(
      req.user.id,
      update,
      { new: true, runValidators: true }
    ).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const DEFAULT_NEARBY_RADIUS_KM = Number(process.env.NEARBY_DRIVER_RADIUS_KM) || 15;
const DRIVER_LOCATION_TTL_MINUTES = Number(process.env.DRIVER_LOCATION_TTL_MINUTES) || 5;

const publicDriverProjection = {
  name: 1,
  vehicleNumber: 1,
  vehicleType: 1,
  ratePerKm: 1,
  pricingMode: 1,
  area: 1,
  qrCode: 1,
  isVerified: 1,
  location: 1,
};
const getDriverProfile = async (req, res) => {
  try {
    const driver = await Driver.findById(req.user.id).select('-password');
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    const config = await SystemConfig.findOne().lean();
    const effectiveMode = driver.pricingMode || config?.rateMode || 'ADMIN';
    const driverObj = driver.toObject();
    driverObj.pricingMode = effectiveMode;
    res.json(driverObj);
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
      pricingMode: driver.pricingMode,
    });

    const qrCode = await QRCode.toDataURL(qrPayload);
    driver.qrCode = qrCode;
    await driver.save();

    res.json({ qrCode });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Returns verified drivers within the configured radius of a pickup point.
const getNearbyDrivers = async (req, res) => {
  const { area, lat, lng } = req.query;
  const pickupLat = lat == null ? null : Number(lat);
  const pickupLng = lng == null ? null : Number(lng);
  const hasPickup = Number.isFinite(pickupLat) && Number.isFinite(pickupLng);
  const maxDistanceMeters = DEFAULT_NEARBY_RADIUS_KM * 1000;
  const locationFreshAfter = new Date(Date.now() - DRIVER_LOCATION_TTL_MINUTES * 60 * 1000);

  try {
    if (!hasPickup) {
      const baseMatch = area ? { area, isVerified: true } : { isVerified: true };
      const drivers = await Driver.find(baseMatch)
        .select('name vehicleNumber vehicleType ratePerKm pricingMode area qrCode isVerified location')
        .lean();
      return res.json(await withEffectiveRates(drivers));
    }

    const drivers = await Driver.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: [pickupLng, pickupLat] },
          distanceField: 'distanceMeters',
          maxDistance: maxDistanceMeters,
          spherical: true,
          query: {
            isVerified: true,
            'location.coordinates': { $exists: true, $ne: [] },
            'location.updatedAt': { $gte: locationFreshAfter },
          },
        },
      },
      { $sort: { distanceMeters: 1 } },
      {
        $project: {
          ...publicDriverProjection,
          distanceMeters: 1,
          distanceKm: { $round: [{ $divide: ['$distanceMeters', 1000] }, 2] },
        },
      },
    ]);

    return res.json(await withEffectiveRates(drivers, { lat: pickupLat, lng: pickupLng }));
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
    const [priced] = await withEffectiveRates([driver.toObject()]);
    res.json(priced);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Updates driver's current GPS location - called periodically while driver is online.
const updateLocation = async (req, res) => {
  const lat = Number(req.body.lat);
  const lng = Number(req.body.lng);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ message: 'Valid lat and lng are required' });
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return res.status(400).json({ message: 'lat or lng is outside valid GPS range' });
  }

  try {
    const driver = await Driver.findByIdAndUpdate(
      req.user.id,
      {
        location: {
          type: 'Point',
          coordinates: [lng, lat],
          lat,
          lng,
          updatedAt: new Date(),
        },
      },
      { new: true }
    ).select('-password');

    const io = req.app?.get('io');
    if (io) {
      Trip.findOne({ driver: req.user.id, status: 'ongoing' }).then((activeTrip) => {
        if (activeTrip) {
          const payload = {
            driverId: req.user.id,
            tripId: activeTrip._id.toString(),
            lat,
            lng,
          };
          if (activeTrip.customer) {
            io.to(activeTrip.customer.toString()).emit('driver_location', payload);
          }
          io.to(activeTrip._id.toString()).emit('driver_location', payload);
        }
      }).catch(() => {});
    }

    res.json(driver);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getDriverProfile, updateDriverProfile, updateQRCode, getNearbyDrivers, getDriverByQR, updateLocation };

