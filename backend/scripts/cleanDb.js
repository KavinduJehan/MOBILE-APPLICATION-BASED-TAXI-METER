/**
 * Database cleaner script for Taxi Meter System
 * Usage:
 *   node scripts/cleanDb.js          (wipes trips, requests, receipts, and customers, preserves admin)
 *   node scripts/cleanDb.js --all    (wipes everything including all drivers, then re-seeds admin)
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const Driver = require('../models/Driver');
const Trip = require('../models/Trip');
const RideRequest = require('../models/RideRequest');
const Receipt = require('../models/Receipt');

const {
  MONGO_URI,
  ADMIN_EMAIL = 'admin@taximeter.com',
  ADMIN_PASSWORD = 'Admin@Taxi2026!',
  ADMIN_NAME = 'Admin',
  ADMIN_PHONE = '0000000000',
} = process.env;

if (!MONGO_URI) {
  console.error('ERROR: MONGO_URI is not set in backend/.env');
  process.exit(1);
}

const wipeAll = process.argv.includes('--all');

async function clean() {
  console.log('Connecting to MongoDB...');
  try {
    await mongoose.connect(MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB.\n');
  } catch (err) {
    console.error('Connection failed:', err.message);
    process.exit(1);
  }

  try {
    // 1. Clear operational collections
    const tripRes = await Trip.deleteMany({});
    console.log(`Deleted ${tripRes.deletedCount} trips.`);

    const reqRes = await RideRequest.deleteMany({});
    console.log(`Deleted ${reqRes.deletedCount} ride requests.`);

    const recRes = await Receipt.deleteMany({});
    console.log(`Deleted ${recRes.deletedCount} receipts.`);

    // 2. Clear customer collections if any exist
    try {
      const Customer = require('../models/Customer');
      const custRes = await Customer.deleteMany({});
      console.log(`Deleted ${custRes.deletedCount} customers.`);
    } catch (_) {}

    // 3. Clear drivers
    if (wipeAll) {
      console.log('Wiping all drivers and recreating admin account...');
      await Driver.deleteMany({});

      const hash = await bcrypt.hash(ADMIN_PASSWORD, 10);
      await Driver.create({
        name: ADMIN_NAME,
        email: ADMIN_EMAIL.toLowerCase(),
        password: hash,
        phone: ADMIN_PHONE,
        licenseNumber: 'REG-0001',
        vehicleNumber: 'REG-0001',
        area: 'Colombo',
        ratePerKm: 50,
        isVerified: true,
        role: 'admin',
      });
      console.log(`Admin account recreated (${ADMIN_EMAIL}).`);
    } else {
      // Keep admin account, delete non-admin drivers
      const driverRes = await Driver.deleteMany({
        email: { $ne: ADMIN_EMAIL.toLowerCase() },
      });
      console.log(`Deleted ${driverRes.deletedCount} non-admin drivers (Admin account preserved).`);
    }

    console.log('\nDatabase cleanup complete!');
  } catch (err) {
    console.error('Error during cleanup:', err.message);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB.');
    process.exit(0);
  }
}

clean();
