const { test } = require('node:test');
const assert = require('node:assert/strict');
const { issueIdentity, verifyIdentity } = require('../services/offlineIdentity');
const { validateOfflineSnapshot } = require('../services/offlineTripValidation');

process.env.JWT_SECRET = 'offline-unit-test-secret';
const now = Date.UTC(2026, 9, 9, 10);
const driver = { _id: 'driver-1', qrToken: 'qr-1', pricingMode: 'ADMIN', ratePerKm: 999 };
const valid = () => ({ version: 1, localId: `offline-${'a'.repeat(32)}`,
  driverId: 'driver-1', driverToken: 'qr-1', customerId: 'customer-1',
  customerIdentity: issueIdentity('customer-1', now - 1000),
  ratePerKm: 80, distanceKm: 12.5, totalFare: 1000, status: 'completed',
  offerTimestamp: new Date(now).toISOString(), startTime: new Date(now).toISOString(),
  endTime: new Date(now + 600000).toISOString() });

test('offline fare preserves the agreed rate independently of current pricing', () => {
  const result = validateOfflineSnapshot(valid(), driver, now + 600000);
  assert.equal(result.ratePerKm, 80);
  assert.equal(result.totalFare, 1000);
  assert.equal(result.customer, 'customer-1');
  assert.equal(result.receiptNumber, `REC-OFFLINE-${'A'.repeat(32)}`);
});
test('identity proof cannot be reassigned, modified or used after its offline window', () => {
  const identity = issueIdentity('customer-1', now);
  assert.equal(verifyIdentity(identity, 'customer-1', new Date(now)), true);
  assert.equal(verifyIdentity(identity, 'customer-2', new Date(now)), false);
  assert.equal(verifyIdentity(`${identity}x`, 'customer-1', new Date(now)), false);
  assert.equal(verifyIdentity(identity, 'customer-1', new Date(now + 31 * 86400000)), false);
});
test('delayed sync verifies identity at trip start, not upload time', () => {
  const item = valid();
  assert.equal(validateOfflineSnapshot(item, driver, now + 45 * 86400000).customer, 'customer-1');
});
test('unproven customer IDs never attach a trip to another customer account', () => {
  const item = valid();
  item.customerIdentity = 'fake';
  assert.equal(validateOfflineSnapshot(item, driver, now + 600000).customer, null);
});
test('wrong driver, unfinished trip, invalid numbers and tampered total are rejected', () => {
  for (const change of [{ driverId: 'other' }, { driverToken: 'other' }, { status: 'ongoing' },
    { ratePerKm: 0 }, { distanceKm: -1 }, { distanceKm: Infinity }, { totalFare: 2 },
    { endTime: 'bad' }, { endTime: new Date(now - 1).toISOString() },
    { offerTimestamp: new Date(now - 31 * 60000).toISOString() }]) {
    assert.throws(() => validateOfflineSnapshot({ ...valid(), ...change }, driver, now + 600000));
  }
});

test('sync retries reuse the trip and recover a receipt after a partial failure', async (t) => {
  t.mock.method(Date, 'now', () => now + 600000);
  const Trip = require('../models/Trip');
  const Receipt = require('../models/Receipt');
  const Driver = require('../models/Driver');
  const Customer = require('../models/Customer');
  const { syncOfflineHandshakeTrips } = require('../controllers/offlineTripController');
  let storedTrip, storedReceipt, failReceipt = true, tripCreates = 0;
  t.mock.method(Driver, 'findById', async () => driver);
  t.mock.method(Customer, 'exists', async () => true);
  t.mock.method(Receipt, 'findOne', async () => storedReceipt);
  t.mock.method(Trip, 'findOneAndUpdate', async (filter, update) => {
    assert.deepEqual(filter, { driver: 'driver-1', offlineLocalId: valid().localId });
    if (!storedTrip) { tripCreates++; storedTrip = { _id: 'server-trip-1', ...update.$setOnInsert }; }
    return storedTrip;
  });
  t.mock.method(Receipt, 'findOneAndUpdate', async (filter, update) => {
    if (failReceipt) { failReceipt = false; throw new Error('Simulated receipt write failure'); }
    storedReceipt ||= { _id: 'receipt-1', ...update.$setOnInsert };
    return storedReceipt;
  });
  const request = { user: { id: 'driver-1', role: 'driver' }, body: { trips: [valid()] } };
  const response = () => ({ code: 200, body: null,
    status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } });
  const first = response();
  await syncOfflineHandshakeTrips(request, first);
  assert.equal(first.code, 500);
  const retry = response();
  await syncOfflineHandshakeTrips(request, retry);
  assert.equal(retry.code, 200);
  assert.equal(retry.body.idMap[valid().localId], 'server-trip-1');
  const repeated = response();
  await syncOfflineHandshakeTrips(request, repeated);
  assert.equal(repeated.code, 200);
  assert.equal(tripCreates, 1);
  assert.equal(storedReceipt.totalFare, 1000);
});

test('a customer cannot upload a driver trip', async () => {
  const { syncOfflineHandshakeTrips } = require('../controllers/offlineTripController');
  const response = { code: 200, status(code) { this.code = code; return this; }, json(body) { this.body = body; } };
  await syncOfflineHandshakeTrips({ user: { id: 'customer-1', role: 'customer' }, body: { trips: [valid()] } }, response);
  assert.equal(response.code, 403);
});
