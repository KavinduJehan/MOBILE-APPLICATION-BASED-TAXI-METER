/**
 * Run once to create the initial regulator (admin) account.
 * Usage: node scripts/seedAdmin.js
 *
 * Reads credentials from environment variables:
 *   ADMIN_EMAIL    (required)
 *   ADMIN_PASSWORD (required)
 *   ADMIN_NAME     (optional, defaults to "Admin")
 *   ADMIN_PHONE    (optional, defaults to "0000000000")
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const Driver = require('../models/Driver');

const {
  ADMIN_EMAIL,
  ADMIN_PASSWORD,
  ADMIN_NAME = 'Admin',
  ADMIN_PHONE = '0000000000',
  MONGO_URI,
} = process.env;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('ERROR: ADMIN_EMAIL and ADMIN_PASSWORD must be set in .env');
  process.exit(1);
}

if (!MONGO_URI) {
  console.error('ERROR: MONGO_URI must be set in .env');
  process.exit(1);
}

(async () => {
  console.log('Connecting to MongoDB...');
  try {
    await mongoose.connect(MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected.');
  } catch (err) {
    console.error('ERROR: Could not connect to MongoDB:', err.message);
    console.error('Check that MONGO_URI in .env is correct and the database is reachable.');
    process.exit(1);
  }

  const existing = await Driver.findOne({ email: ADMIN_EMAIL });
  if (existing) {
    console.log(`Admin account already exists for ${ADMIN_EMAIL}. No changes made.`);
    await mongoose.disconnect();
    process.exit(0);
  }

  await Driver.create({
    name: ADMIN_NAME,
    email: ADMIN_EMAIL,
    phone: ADMIN_PHONE,
    password: ADMIN_PASSWORD,
    licenseNumber: `ADMIN-${Date.now()}`,
    vehicleNumber: 'ADMIN',
    role: 'regulator',
    isVerified: true,
  });

  console.log(`Regulator account created: ${ADMIN_EMAIL}`);
  await mongoose.disconnect();
  process.exit(0);
})();
