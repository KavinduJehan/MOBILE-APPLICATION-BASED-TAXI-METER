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
const connectDB = require('../config/db');

const {
  ADMIN_EMAIL,
  ADMIN_PASSWORD,
  ADMIN_NAME = 'Admin',
  ADMIN_PHONE = '0000000000',
} = process.env;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('ERROR: ADMIN_EMAIL and ADMIN_PASSWORD must be set in .env');
  process.exit(1);
}

(async () => {
  await connectDB();

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
