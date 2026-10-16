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
const bcrypt = require('bcryptjs');
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

  const existing = await Driver.findOne({
    $or: [{ email: ADMIN_EMAIL.toLowerCase() }, { phone: ADMIN_PHONE }],
  });
  if (existing) {
    if (existing.email === ADMIN_EMAIL.toLowerCase()) {
      // Migrate admins created before the first-login flag existed.
      const storedAdmin = await Driver.collection.findOne(
        { _id: existing._id },
        { projection: { requiresPasswordChange: 1 } }
      );
      if (existing.role === 'regulator' && storedAdmin.requiresPasswordChange === undefined) {
        await Driver.collection.updateOne(
          { _id: existing._id },
          { $set: { requiresPasswordChange: true } }
        );
        console.log('Existing admin will be required to change the password at next login.');
      }
      console.log(`Admin account already exists for ${ADMIN_EMAIL}. Password left unchanged.`);
    } else {
      console.error(
        `ERROR: ADMIN_PHONE ${ADMIN_PHONE} is already used by another account. ` +
          'Set a different ADMIN_PHONE in .env and run this script again.'
      );
    }
    await mongoose.disconnect();
    process.exit(existing.email === ADMIN_EMAIL.toLowerCase() ? 0 : 1);
  }

  const seededAdmin = new Driver({
    name: ADMIN_NAME,
    email: ADMIN_EMAIL,
    phone: ADMIN_PHONE,
    password: await bcrypt.hash(ADMIN_PASSWORD, 12),
    licenseNumber: `ADMIN-${Date.now()}`,
    vehicleNumber: 'ADMIN',
    role: 'regulator',
    isVerified: true,
    requiresPasswordChange: true,
  });
  seededAdmin.$locals.passwordIsHashed = true;
  await seededAdmin.save();

  console.log(`Regulator account created: ${ADMIN_EMAIL}`);
  await mongoose.disconnect();
  process.exit(0);
})();
