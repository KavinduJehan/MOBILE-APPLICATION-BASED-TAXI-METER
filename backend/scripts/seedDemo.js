/**
 * Demo seed script — fills the DB with realistic fake data for viva/demo purposes.
 * Usage: node scripts/seedDemo.js
 *
 * Safe to run multiple times — clears previous demo data first (preserves the
 * admin/regulator account).
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const RideRequest = require('../models/RideRequest');
const Receipt = require('../models/Receipt');

// ─── Helpers ────────────────────────────────────────────────────────────────

const rand = (min, max) => +(Math.random() * (max - min) + min).toFixed(2);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

function daysAgo(n, offsetHours = 0) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(d.getHours() - offsetHours);
  return d;
}

let receiptCounter = 1;
function receiptNumber() {
  return `RCP-${String(receiptCounter++).padStart(5, '0')}`;
}

// ─── Static data ────────────────────────────────────────────────────────────

const AREAS = ['Colombo', 'Kandy', 'Galle', 'Negombo', 'Jaffna', 'Matara', 'Kurunegala'];

const DRIVER_PROFILES = [
  { name: 'Amal Perera',    email: 'amal@demo.com',    phone: '+94771000001', licenseNumber: 'WP-1234-DL', vehicleNumber: 'CAB-1001', area: 'Colombo',    ratePerKm: 65,  isVerified: true  },
  { name: 'Nimal Silva',    email: 'nimal@demo.com',   phone: '+94772000002', licenseNumber: 'CP-5678-DL', vehicleNumber: 'CAB-1002', area: 'Kandy',      ratePerKm: 60,  isVerified: true  },
  { name: 'Kasun Fernando', email: 'kasun@demo.com',   phone: '+94773000003', licenseNumber: 'SB-9012-DL', vehicleNumber: 'CAB-1003', area: 'Galle',      ratePerKm: 55,  isVerified: true  },
  { name: 'Dinesh Jayawardena', email: 'dinesh@demo.com', phone: '+94774000004', licenseNumber: 'NW-3456-DL', vehicleNumber: 'CAB-1004', area: 'Negombo',   ratePerKm: 70,  isVerified: true  },
  { name: 'Ruwan Bandara',  email: 'ruwan@demo.com',   phone: '+94775000005', licenseNumber: 'NC-7890-DL', vehicleNumber: 'CAB-1005', area: 'Jaffna',     ratePerKm: 58,  isVerified: false },
  { name: 'Priya Kumari',   email: 'priya@demo.com',   phone: '+94776000006', licenseNumber: 'SB-1122-DL', vehicleNumber: 'CAB-1006', area: 'Matara',     ratePerKm: 62,  isVerified: false },
  { name: 'Chamara Dissanayake', email: 'chamara@demo.com', phone: '+94777000007', licenseNumber: 'NW-3344-DL', vehicleNumber: 'CAB-1007', area: 'Kurunegala', ratePerKm: 57, isVerified: true },
];

const CUSTOMER_NAMES = ['Saman Kumara', 'Malini De Silva', 'Rohan Wijeratne', 'Thilini Perera', 'Nuwan Rajapaksa', 'Anoma Wickramasinghe', 'Isuru Gunasekara', 'Nadeesha Rodrigo', 'Anonymous'];

const ROUTE_PAIRS = [
  { start: 'Fort Railway Station, Colombo',   end: 'Bandaranaike International Airport',  km: 34 },
  { start: 'Pettah Bus Stand, Colombo',       end: 'Nugegoda Junction',                   km: 8  },
  { start: 'Kandy City Centre',               end: 'Peradeniya University',               km: 6  },
  { start: 'Galle Fort',                      end: 'Unawatuna Beach',                     km: 5  },
  { start: 'Negombo Town',                    end: 'Katunayake Airport',                  km: 10 },
  { start: 'Majestic City, Colombo',          end: 'Rajagiriya Interchange',              km: 5  },
  { start: 'Kurunegala Town',                 end: 'Dambulla Bus Stand',                  km: 72 },
  { start: 'Matara Bus Station',              end: 'Tangalle Beach',                      km: 29 },
  { start: 'Jaffna Town',                     end: 'Nainativu Ferry Point',               km: 18 },
  { start: 'Colpetty, Colombo',               end: 'Battaramulla Town',                   km: 12 },
  { start: 'Wellawatte Junction',             end: 'Borella Cemetery Junction',           km: 6  },
  { start: 'Bambalapitiya, Colombo',          end: 'Dehiwala Zoo',                        km: 4  },
];

// ─── Main ────────────────────────────────────────────────────────────────────

(async () => {
  console.log('Connecting to MongoDB...');
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected.');
  } catch (err) {
    console.error('Could not connect:', err.message);
    process.exit(1);
  }

  // ── Wipe previous demo data (keep the regulator account) ──────────────────
  console.log('Clearing previous demo data...');
  await Driver.deleteMany({ email: { $in: DRIVER_PROFILES.map((d) => d.email) } });
  await Trip.deleteMany({});
  await RideRequest.deleteMany({});
  await Receipt.deleteMany({});
  console.log('Cleared.');

  // ── Create drivers ────────────────────────────────────────────────────────
  console.log('Creating drivers...');
  const drivers = [];
  for (const profile of DRIVER_PROFILES) {
    const driver = await Driver.create({
      ...profile,
      password: 'Driver@2026!',
      qrToken: uuidv4(),
    });
    drivers.push(driver);
  }
  console.log(`Created ${drivers.length} drivers.`);

  // ── Create trips & receipts ───────────────────────────────────────────────
  console.log('Creating trips & receipts...');
  const trips = [];

  for (const driver of drivers) {
    // 4–8 completed trips per driver, spread over last 30 days
    const tripCount = Math.floor(Math.random() * 5) + 4;
    for (let i = 0; i < tripCount; i++) {
      const route = pick(ROUTE_PAIRS);
      const km = +(route.km * rand(0.9, 1.15)).toFixed(2);
      const rate = driver.ratePerKm;
      const fare = +(km * rate).toFixed(2);
      const daysBack = Math.floor(Math.random() * 30);
      const startTime = daysAgo(daysBack, Math.floor(Math.random() * 18));
      const endTime = new Date(startTime.getTime() + km * 2.5 * 60 * 1000); // ~2.5 min/km

      const trip = await Trip.create({
        driver: driver._id,
        customerName: pick(CUSTOMER_NAMES),
        startLocation: route.start,
        endLocation: route.end,
        distanceKm: km,
        ratePerKm: rate,
        totalFare: fare,
        startTime,
        endTime,
        status: 'completed',
        syncedToCloud: true,
      });
      trips.push(trip);

      await Receipt.create({
        trip: trip._id,
        driver: driver._id,
        receiptNumber: receiptNumber(),
        customerName: trip.customerName,
        distanceKm: km,
        ratePerKm: rate,
        totalFare: fare,
        issuedAt: endTime,
      });
    }

    // 1 ongoing trip for the first two verified drivers
    if (drivers.indexOf(driver) < 2) {
      const route = pick(ROUTE_PAIRS);
      const km = +(route.km * rand(0.9, 1.15)).toFixed(2);
      await Trip.create({
        driver: driver._id,
        customerName: pick(CUSTOMER_NAMES),
        startLocation: route.start,
        endLocation: route.end,
        distanceKm: km,
        ratePerKm: driver.ratePerKm,
        totalFare: +(km * driver.ratePerKm).toFixed(2),
        startTime: daysAgo(0, 0),
        status: 'ongoing',
        syncedToCloud: false,
      });
    }
  }
  console.log(`Created ${trips.length} completed trips + receipts + 2 ongoing trips.`);

  // ── Create ride requests ──────────────────────────────────────────────────
  console.log('Creating ride requests...');

  // Colombo area coords
  const baseCoords = [
    { lat: 6.9271, lng: 79.8612 }, // Colombo Fort
    { lat: 6.8820, lng: 79.8674 }, // Dehiwala
    { lat: 6.9147, lng: 79.9728 }, // Rajagiriya
    { lat: 7.2906, lng: 80.6337 }, // Kandy
    { lat: 6.0329, lng: 80.2168 }, // Galle
  ];

  for (const driver of drivers) {
    // 2 accepted requests
    for (let i = 0; i < 2; i++) {
      const pickup = pick(baseCoords);
      const dest = pick(baseCoords);
      const km = rand(3, 20);
      const driverRate = driver.ratePerKm;
      const route = pick(ROUTE_PAIRS);
      await RideRequest.create({
        driver: driver._id,
        customerName: pick(CUSTOMER_NAMES),
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        pickupAddress: route.start,
        destLat: dest.lat,
        destLng: dest.lng,
        destAddress: route.end,
        estimatedDistanceKm: km,
        driverRatePerKm: driverRate,
        suggestedRatePerKm: null,
        agreedRatePerKm: driverRate,
        status: 'accepted',
        syncedToCloud: true,
      });
    }

    // 1 pending request
    const pickup = pick(baseCoords);
    const dest = pick(baseCoords);
    const route = pick(ROUTE_PAIRS);
    const driverRate = driver.ratePerKm;
    await RideRequest.create({
      driver: driver._id,
      customerName: pick(CUSTOMER_NAMES),
      pickupLat: pickup.lat,
      pickupLng: pickup.lng,
      pickupAddress: route.start,
      destLat: dest.lat,
      destLng: dest.lng,
      destAddress: route.end,
      estimatedDistanceKm: rand(3, 15),
      driverRatePerKm: driverRate,
      suggestedRatePerKm: +(driverRate * 0.9).toFixed(2), // customer negotiated 10% off
      agreedRatePerKm: null,
      status: 'pending',
      syncedToCloud: true,
    });
  }
  console.log('Created ride requests.');

  // ── Summary ───────────────────────────────────────────────────────────────
  const [driverCount, tripCount, requestCount, receiptCount] = await Promise.all([
    Driver.countDocuments({ role: 'driver' }),
    Trip.countDocuments(),
    RideRequest.countDocuments(),
    Receipt.countDocuments(),
  ]);

  console.log('\n✔ Demo data ready:');
  console.log(`  Drivers:       ${driverCount} (${DRIVER_PROFILES.filter(d => d.isVerified).length} verified, ${DRIVER_PROFILES.filter(d => !d.isVerified).length} unverified)`);
  console.log(`  Trips:         ${tripCount}`);
  console.log(`  Ride requests: ${requestCount}`);
  console.log(`  Receipts:      ${receiptCount}`);
  console.log('\nAll driver passwords: Driver@2026!');

  await mongoose.disconnect();
})();
