const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../app');
const Driver = require('../models/Driver');
const Customer = require('../models/Customer');

let customerToken;
let driverToken;
let driverId;
let tripId;

const asCustomer = (req) => req.set('Authorization', `Bearer ${customerToken}`);
const asDriver = (req) => req.set('Authorization', `Bearer ${driverToken}`);

beforeEach(async () => {
  const customer = await Customer.create({
    name: 'Sync Customer',
    email: 'sync.customer@test.com',
    phone: '0717778888',
  });
  customerToken = jwt.sign(
    { id: customer._id, name: customer.name, role: 'customer' },
    process.env.JWT_SECRET
  );

  const res = await request(app).post('/api/auth/register').send({
    name: 'Sync Driver',
    email: 'syncdriver@test.com',
    phone: '0777778888',
    password: 'password123',
    licenseNumber: 'LIC-SYNC-01',
    vehicleNumber: 'CAR-SYNC-01',
    area: 'Colombo',
  });
  driverToken = res.body.token;
  driverId = res.body.driver.id;
  await Driver.findByIdAndUpdate(driverId, {
    isVerified: true,
    ratePerKm: 80,
    pricingMode: 'DRIVER',
    location: {
      type: 'Point',
      coordinates: [79.8612, 6.9271],
      lat: 6.9271,
      lng: 79.8612,
      updatedAt: new Date(),
    },
  });

  // Customer requests, driver accepts -> an ongoing trip both can see
  const ride = await asCustomer(request(app).post('/api/ride-requests')).send({
    driverId,
    pickupLat: 6.9271,
    pickupLng: 79.8612,
    pickupAddress: 'Colombo Fort',
    destLat: 6.8735,
    destLng: 79.8874,
    destAddress: 'Dehiwala',
    estimatedDistanceKm: 10,
  });
  const accepted = await asDriver(
    request(app).patch(`/api/ride-requests/${ride.body._id}/respond`)
  ).send({ action: 'accept' });
  tripId = accepted.body.trip._id;
});

describe('trip state shared by driver and customer', () => {
  it('trip details carry the driver\'s live position for the customer', async () => {
    const res = await asCustomer(request(app).get(`/api/trips/${tripId}`));
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ongoing');
    expect(res.body.pickedUpAt).toBeNull();
    expect(res.body.driver.location.lat).toBe(6.9271);
    expect(res.body.driver.location.lng).toBe(79.8612);
  });

  it('the customer sees when the driver has arrived at the pickup point', async () => {
    const before = await asCustomer(request(app).get(`/api/trips/${tripId}`));
    expect(before.body.arrivedAt).toBeNull();

    const arrived = await asDriver(request(app).patch(`/api/trips/${tripId}/arrive`));
    expect(arrived.statusCode).toBe(200);

    const after = await asCustomer(request(app).get(`/api/trips/${tripId}`));
    expect(after.body.arrivedAt).toBeTruthy();
    expect(after.body.pickedUpAt).toBeNull();
  });

  it('only the driver can mark the arrival', async () => {
    const res = await asCustomer(request(app).patch(`/api/trips/${tripId}/arrive`));
    expect(res.statusCode).toBe(403);
  });

  it('starting the trip marks the customer as picked up', async () => {
    const started = await asDriver(request(app).patch(`/api/trips/${tripId}/start`));
    expect(started.statusCode).toBe(200);

    const res = await asCustomer(request(app).get(`/api/trips/${tripId}`));
    expect(res.body.pickedUpAt).toBeTruthy();
  });

  it('when the customer ends the trip, the driver sees it completed with the same receipt', async () => {
    const byCustomer = await asCustomer(request(app).patch(`/api/trips/${tripId}/end`));
    expect(byCustomer.statusCode).toBe(200);
    expect(byCustomer.body.trip.status).toBe('completed');

    const seenByDriver = await asDriver(request(app).get(`/api/trips/${tripId}`));
    expect(seenByDriver.body.status).toBe('completed');

    // The driver app then "ends" it too to fetch the summary: same receipt, no duplicate
    const byDriver = await asDriver(request(app).patch(`/api/trips/${tripId}/end`));
    expect(byDriver.statusCode).toBe(200);
    expect(byDriver.body.receipt.receiptNumber).toBe(byCustomer.body.receipt.receiptNumber);
  });

  it('when the driver ends the trip, the customer sees it completed with the same receipt', async () => {
    const byDriver = await asDriver(request(app).patch(`/api/trips/${tripId}/end`));
    expect(byDriver.body.trip.status).toBe('completed');

    const seenByCustomer = await asCustomer(request(app).get(`/api/trips/${tripId}`));
    expect(seenByCustomer.body.status).toBe('completed');

    const byCustomer = await asCustomer(request(app).patch(`/api/trips/${tripId}/end`));
    expect(byCustomer.body.receipt.receiptNumber).toBe(byDriver.body.receipt.receiptNumber);
  });

  it('a cancelled trip is visible as cancelled to the other side', async () => {
    const cancelled = await asCustomer(request(app).patch(`/api/trips/${tripId}/cancel`));
    expect(cancelled.statusCode).toBe(200);

    const seenByDriver = await asDriver(request(app).get(`/api/trips/${tripId}`));
    expect(seenByDriver.body.status).toBe('cancelled');
  });

  it('other users cannot read the trip', async () => {
    const stranger = jwt.sign(
      { id: '000000000000000000000009', name: 'Stranger', role: 'customer' },
      process.env.JWT_SECRET
    );
    const res = await request(app)
      .get(`/api/trips/${tripId}`)
      .set('Authorization', `Bearer ${stranger}`);
    expect(res.statusCode).toBe(403);
  });
});
