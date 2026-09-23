const request = require('supertest');
const app = require('../app');
const Driver = require('../models/Driver');
const Customer = require('../models/Customer');
const jwt = require('jsonwebtoken');

let customerToken;

beforeEach(async () => {
  const customer = await Customer.create({
    name: 'Test Customer',
    email: 'ride.customer@test.com',
    phone: '0712345678',
  });
  customerToken = jwt.sign(
    { id: customer._id, name: customer.name, role: 'customer' },
    process.env.JWT_SECRET
  );
});

const postRideRequest = () =>
  request(app)
    .post('/api/ride-requests')
    .set('Authorization', `Bearer ${customerToken}`);

const driverData = {
  name: 'Ride Driver',
  email: 'ridedriver@test.com',
  phone: '0772222222',
  password: 'password123',
  licenseNumber: 'LIC-RIDE-01',
  vehicleNumber: 'CAR-RIDE-01',
  area: 'Colombo',
};

const registerAndLogin = async (data = driverData) => {
  const res = await request(app).post('/api/auth/register').send(data);
  return { token: res.body.token, driver: res.body.driver };
};

const buildRideRequest = (driverId, overrides = {}) => ({
  driverId,
  customerName: 'Test Customer',
  pickupLat: 6.9271,
  pickupLng: 79.8612,
  pickupAddress: 'Colombo Fort',
  destLat: 6.8735,
  destLng: 79.8874,
  destAddress: 'Dehiwala',
  estimatedDistanceKm: 8.5,
  ...overrides,
});

// ─── Driver location update ──────────────────────────────────────────────────

describe('PATCH /api/drivers/location', () => {
  it('updates driver location when authenticated', async () => {
    const { token } = await registerAndLogin();
    const res = await request(app)
      .patch('/api/drivers/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ lat: 6.9271, lng: 79.8612 });
    expect(res.statusCode).toBe(200);
    expect(res.body.location.lat).toBe(6.9271);
    expect(res.body.location.lng).toBe(79.8612);
  });

  it('returns 400 if lat or lng is missing', async () => {
    const { token } = await registerAndLogin();
    const res = await request(app)
      .patch('/api/drivers/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ lat: 6.9271 });
    expect(res.statusCode).toBe(400);
  });

  it('returns 401 without a token', async () => {
    const res = await request(app)
      .patch('/api/drivers/location')
      .send({ lat: 6.9271, lng: 79.8612 });
    expect(res.statusCode).toBe(401);
  });
});

// ─── Create ride request ─────────────────────────────────────────────────────

describe('POST /api/ride-requests', () => {
  it('requires an authenticated customer', async () => {
    const res = await request(app).post('/api/ride-requests').send({});
    expect(res.statusCode).toBe(401);
  });

  it('creates a ride request for a verified driver', async () => {
    const { driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });

    const res = await postRideRequest()
      .send(buildRideRequest(driver.id));
    expect(res.statusCode).toBe(201);
    expect(res.body.status).toBe('pending');
    expect(res.body.driverRatePerKm).toBe(80);
    expect(res.body.suggestedRatePerKm).toBeNull();
  });

  it('prevents a customer from booking while another request is pending', async () => {
    const { driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });

    const first = await postRideRequest().send(buildRideRequest(driver.id));
    const second = await postRideRequest().send(buildRideRequest(driver.id));

    expect(first.statusCode).toBe(201);
    expect(second.statusCode).toBe(409);
    expect(second.body.code).toBe('ACTIVE_RIDE_EXISTS');
  });

  it('allows another booking after the previous request is rejected', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const first = await postRideRequest().send(buildRideRequest(driver.id));

    await request(app)
      .patch(`/api/ride-requests/${first.body._id}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'reject' });

    const second = await postRideRequest().send(buildRideRequest(driver.id));
    expect(second.statusCode).toBe(201);
  });

  it('creates a ride request with a negotiated rate', async () => {
    const { driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });

    const res = await postRideRequest()
      .send(buildRideRequest(driver.id, { suggestedRatePerKm: 65 }));
    expect(res.statusCode).toBe(201);
    expect(res.body.suggestedRatePerKm).toBe(65);
  });

  it('returns 403 if driver is not verified', async () => {
    const { driver } = await registerAndLogin();
    const res = await postRideRequest()
      .send(buildRideRequest(driver.id));
    expect(res.statusCode).toBe(403);
  });

  it('ignores suggestedRatePerKm when it exceeds driver rate (no negotiation)', async () => {
    const { driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });

    const res = await postRideRequest()
      .send(buildRideRequest(driver.id, { suggestedRatePerKm: 100 }));
    expect(res.statusCode).toBe(201);
    expect(res.body.suggestedRatePerKm).toBeNull();
  });

  it('returns 400 if required fields are missing', async () => {
    const res = await postRideRequest()
      .send({ driverId: '000000000000000000000000' });
    expect(res.statusCode).toBe(400);
  });

  it('returns 404 for a non-existent driver', async () => {
    const res = await postRideRequest()
      .send(buildRideRequest('000000000000000000000000'));
    expect(res.statusCode).toBe(404);
  });
});

// ─── Driver views incoming requests ──────────────────────────────────────────

describe('GET /api/ride-requests/incoming', () => {
  it('returns pending requests for the logged-in driver', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    await postRideRequest().send(buildRideRequest(driver.id));

    const res = await request(app)
      .get('/api/ride-requests/incoming')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.length).toBe(1);
    expect(res.body[0].status).toBe('pending');
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).get('/api/ride-requests/incoming');
    expect(res.statusCode).toBe(401);
  });
});

// ─── Driver responds to request ───────────────────────────────────────────────

describe('PATCH /api/ride-requests/:id/respond', () => {
  it('driver accepts request and trip is auto-created', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id));
    const rideId = rideRes.body._id;

    const res = await request(app)
      .patch(`/api/ride-requests/${rideId}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'accept' });
    expect(res.statusCode).toBe(200);
    expect(res.body.rideRequest.status).toBe('accepted');
    expect(res.body.trip).toBeDefined();
    expect(res.body.trip.status).toBe('ongoing');
    expect(res.body.trip.totalFare).toBe(8.5 * 80);
  });

  it('uses negotiated rate when driver accepts a negotiation', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id, { suggestedRatePerKm: 65 }));
    const rideId = rideRes.body._id;

    const res = await request(app)
      .patch(`/api/ride-requests/${rideId}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'accept' });
    expect(res.statusCode).toBe(200);
    expect(res.body.rideRequest.agreedRatePerKm).toBe(65);
    expect(res.body.trip.totalFare).toBe(8.5 * 65);
  });

  it('driver rejects a request', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id));

    const res = await request(app)
      .patch(`/api/ride-requests/${rideRes.body._id}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'reject' });
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('rejected');
  });

  it('returns 409 if request is already accepted', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id));
    const rideId = rideRes.body._id;

    await request(app)
      .patch(`/api/ride-requests/${rideId}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'accept' });

    const res = await request(app)
      .patch(`/api/ride-requests/${rideId}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'accept' });
    expect(res.statusCode).toBe(409);
  });

  it('returns 400 for an invalid action', async () => {
    const { token, driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id));

    const res = await request(app)
      .patch(`/api/ride-requests/${rideRes.body._id}/respond`)
      .set('Authorization', `Bearer ${token}`)
      .send({ action: 'maybe' });
    expect(res.statusCode).toBe(400);
  });
});

// ─── Customer polls request status ───────────────────────────────────────────

describe('GET /api/ride-requests/:id/status', () => {
  it('returns the current status of a ride request', async () => {
    const { driver } = await registerAndLogin();
    await Driver.findByIdAndUpdate(driver.id, { isVerified: true, ratePerKm: 80 });
    const rideRes = await postRideRequest()
      .send(buildRideRequest(driver.id));

    const res = await request(app)
      .get(`/api/ride-requests/${rideRes.body._id}/status`);
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('pending');
  });

  it('returns 404 for a non-existent request', async () => {
    const res = await request(app)
      .get('/api/ride-requests/000000000000000000000000/status');
    expect(res.statusCode).toBe(404);
  });
});
