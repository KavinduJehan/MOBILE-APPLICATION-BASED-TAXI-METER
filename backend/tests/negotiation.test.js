const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../app');
const Driver = require('../models/Driver');
const Customer = require('../models/Customer');
const RideRequest = require('../models/RideRequest');
const SystemConfig = require('../models/SystemConfig');

let customerToken;
let otherCustomerToken;
let driverToken;
let driverId;

const signCustomer = (customer) => jwt.sign(
  { id: customer._id, name: customer.name, role: 'customer' },
  process.env.JWT_SECRET
);

beforeEach(async () => {
  const customer = await Customer.create({
    name: 'Negotiating Customer',
    email: 'nego.customer@test.com',
    phone: '0713334444',
  });
  const other = await Customer.create({
    name: 'Other Customer',
    email: 'other.customer@test.com',
    phone: '0715556666',
  });
  customerToken = signCustomer(customer);
  otherCustomerToken = signCustomer(other);

  const res = await request(app).post('/api/auth/register').send({
    name: 'Nego Driver',
    email: 'negodriver@test.com',
    phone: '0773334444',
    password: 'password123',
    licenseNumber: 'LIC-NEGO-01',
    vehicleNumber: 'CAR-NEGO-01',
    area: 'Colombo',
  });
  driverToken = res.body.token;
  driverId = res.body.driver.id;
  // Listed rate Rs. 80 / km, driver-set pricing
  await Driver.findByIdAndUpdate(driverId, {
    isVerified: true,
    ratePerKm: 80,
    pricingMode: 'DRIVER',
  });
});

const createRequest = (overrides = {}) => request(app)
  .post('/api/ride-requests')
  .set('Authorization', `Bearer ${customerToken}`)
  .send({
    driverId,
    pickupLat: 6.9271,
    pickupLng: 79.8612,
    pickupAddress: 'Colombo Fort',
    destLat: 6.8735,
    destLng: 79.8874,
    destAddress: 'Dehiwala',
    estimatedDistanceKm: 10,
    ...overrides,
  });

const driverResponds = (id, body) => request(app)
  .patch(`/api/ride-requests/${id}/respond`)
  .set('Authorization', `Bearer ${driverToken}`)
  .send(body);

const customerAnswers = (id, body, token = customerToken) => request(app)
  .patch(`/api/ride-requests/${id}/counter-response`)
  .set('Authorization', `Bearer ${token}`)
  .send(body);

describe('fare negotiation', () => {
  it('marks a request with a lower suggested rate as a customer offer', async () => {
    const res = await createRequest({ suggestedRatePerKm: 60 });
    expect(res.statusCode).toBe(201);
    expect(res.body.suggestedRatePerKm).toBe(60);
    expect(res.body.negotiationStatus).toBe('customer_offered');
    expect(res.body.driverRatePerKm).toBe(80);
  });

  it('has no negotiation when the customer does not suggest a rate', async () => {
    const res = await createRequest();
    expect(res.body.negotiationStatus).toBe('none');
    expect(res.body.suggestedRatePerKm).toBeNull();
  });

  it('ignores the offer when the admin has switched negotiation off', async () => {
    await SystemConfig.findOneAndUpdate({}, { negotiationEnabled: false }, { upsert: true });
    const res = await createRequest({ suggestedRatePerKm: 60 });
    expect(res.statusCode).toBe(201);
    expect(res.body.suggestedRatePerKm).toBeNull();
    expect(res.body.negotiationStatus).toBe('none');
  });

  it('driver accepting the offer starts the trip at the customer rate', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    const res = await driverResponds(body._id, { action: 'accept' });

    expect(res.statusCode).toBe(200);
    expect(res.body.rideRequest.agreedRatePerKm).toBe(60);
    expect(res.body.rideRequest.negotiationStatus).toBe('agreed');
    expect(res.body.trip.ratePerKm).toBe(60);
    expect(res.body.trip.totalFare).toBe(600);
  });

  it('driver rejecting the offer ends the request', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    const res = await driverResponds(body._id, { action: 'reject' });

    expect(res.body.status).toBe('rejected');
    expect(res.body.negotiationStatus).toBe('declined');
    expect(res.body.isActive).toBe(false);
  });

  it('driver can send a counter-offer that keeps the request pending', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    const res = await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('pending');
    expect(res.body.negotiationStatus).toBe('driver_countered');
    expect(res.body.counterRatePerKm).toBe(70);

    const status = await request(app).get(`/api/ride-requests/${body._id}/status`);
    expect(status.body.negotiationStatus).toBe('driver_countered');
    expect(status.body.counterRatePerKm).toBe(70);
  });

  it('rejects a counter outside the customer offer and the listed rate', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });

    for (const counterRatePerKm of [60, 55, 81, 'abc', undefined]) {
      const res = await driverResponds(body._id, { action: 'counter', counterRatePerKm });
      expect(res.statusCode).toBe(400);
    }
    const atListedRate = await driverResponds(body._id, { action: 'counter', counterRatePerKm: 80 });
    expect(atListedRate.statusCode).toBe(200);
  });

  it('does not allow a counter when the customer did not negotiate', async () => {
    const { body } = await createRequest();
    const res = await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });
    expect(res.statusCode).toBe(409);
  });

  it('driver cannot accept or counter again while waiting for the customer', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });

    expect((await driverResponds(body._id, { action: 'accept' })).statusCode).toBe(409);
    expect((await driverResponds(body._id, { action: 'counter', counterRatePerKm: 75 })).statusCode).toBe(409);
    // Withdrawing by rejecting is still allowed
    expect((await driverResponds(body._id, { action: 'reject' })).body.status).toBe('rejected');
  });

  it('customer agreeing to the counter starts the trip at the counter rate', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });

    const res = await customerAnswers(body._id, { action: 'accept' });
    expect(res.statusCode).toBe(200);
    expect(res.body.rideRequest.status).toBe('accepted');
    expect(res.body.rideRequest.agreedRatePerKm).toBe(70);
    expect(res.body.rideRequest.negotiationStatus).toBe('agreed');
    expect(res.body.trip.status).toBe('ongoing');
    expect(res.body.trip.ratePerKm).toBe(70);
    expect(res.body.trip.totalFare).toBe(700);
    expect(res.body.trip.driver).toBe(driverId);

    // The driver can pick the trip up from the status endpoint
    const status = await request(app).get(`/api/ride-requests/${body._id}/status`);
    expect(status.body.status).toBe('accepted');
    expect(status.body.trip.totalFare).toBe(700);
  });

  it('customer declining the counter ends the request and frees them to book again', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });
    await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });

    const res = await customerAnswers(body._id, { action: 'reject' });
    expect(res.statusCode).toBe(200);
    expect(res.body.rideRequest.status).toBe('rejected');
    expect(res.body.rideRequest.negotiationStatus).toBe('declined');

    const stored = await RideRequest.findById(body._id);
    expect(stored.isActive).toBe(false);
    expect((await createRequest()).statusCode).toBe(201);
  });

  it('only the requesting customer can answer, and only when there is a counter', async () => {
    const { body } = await createRequest({ suggestedRatePerKm: 60 });

    // No counter yet
    expect((await customerAnswers(body._id, { action: 'accept' })).statusCode).toBe(409);

    await driverResponds(body._id, { action: 'counter', counterRatePerKm: 70 });
    expect((await customerAnswers(body._id, { action: 'accept' }, otherCustomerToken)).statusCode).toBe(403);
    expect((await customerAnswers(body._id, { action: 'accept' }, driverToken)).statusCode).toBe(403);
    expect((await customerAnswers(body._id, { action: 'maybe' })).statusCode).toBe(400);
  });
});

describe('the rate shown to the customer is the rate that is charged', () => {
  const nearby = () => request(app).get('/api/drivers/nearby?area=Colombo');

  it('DRIVER mode: shows the driver\'s own rate', async () => {
    const res = await nearby();
    const driver = res.body.find((d) => d._id === driverId);
    expect(driver.ratePerKm).toBe(80);

    const ride = await createRequest();
    expect(ride.body.driverRatePerKm).toBe(driver.ratePerKm);
  });

  it('ADMIN mode: shows the regulator rate, not the driver\'s stored rate', async () => {
    await SystemConfig.findOneAndUpdate({}, { rateMode: 'ADMIN', autoBaseRate: 120 }, { upsert: true });
    await Driver.findByIdAndUpdate(driverId, { pricingMode: 'ADMIN', ratePerKm: 80 });

    const res = await nearby();
    const driver = res.body.find((d) => d._id === driverId);
    expect(driver.ratePerKm).toBe(120);
    expect(driver.baseRatePerKm).toBe(80);

    const ride = await createRequest();
    expect(ride.body.driverRatePerKm).toBe(120);
  });

  it('AUTO mode: the listed rate matches the quoted rate on the request', async () => {
    await SystemConfig.findOneAndUpdate({}, { rateMode: 'AUTO', autoBaseRate: 100 }, { upsert: true });
    await Driver.findByIdAndUpdate(driverId, {
      pricingMode: 'AUTO',
      ratePerKm: 55, // stale stored value that must not be shown
      location: { type: 'Point', coordinates: [79.8612, 6.9271], lat: 6.9271, lng: 79.8612, updatedAt: new Date() },
    });

    const res = await request(app).get('/api/drivers/nearby?lat=6.9271&lng=79.8612');
    const driver = res.body.find((d) => d._id === driverId);
    expect(driver.ratePerKm).toBeGreaterThanOrEqual(100);
    expect(driver.ratePerKm).not.toBe(55);

    const ride = await createRequest();
    expect(ride.body.driverRatePerKm).toBe(driver.ratePerKm);
    expect(ride.body.surgeBreakdown).toBeTruthy();
  });

  it('charges the quoted rate on accept even if the live rate has moved', async () => {
    const ride = await createRequest();
    expect(ride.body.driverRatePerKm).toBe(80);
    // The driver's rate changes after the customer was quoted
    await Driver.findByIdAndUpdate(driverId, { ratePerKm: 95 });

    const res = await driverResponds(ride.body._id, { action: 'accept' });
    expect(res.body.rideRequest.agreedRatePerKm).toBe(80);
    expect(res.body.trip.totalFare).toBe(800);
  });

  it('an offer below the listed rate reaches the driver in AUTO mode', async () => {
    await SystemConfig.findOneAndUpdate({}, { rateMode: 'AUTO', autoBaseRate: 100 }, { upsert: true });
    await Driver.findByIdAndUpdate(driverId, { pricingMode: 'AUTO' });

    const ride = await createRequest({ suggestedRatePerKm: 90 });
    expect(ride.body.suggestedRatePerKm).toBe(90);
    expect(ride.body.negotiationStatus).toBe('customer_offered');

    const incoming = await request(app)
      .get('/api/ride-requests/incoming')
      .set('Authorization', `Bearer ${driverToken}`);
    expect(incoming.body[0].suggestedRatePerKm).toBe(90);
  });
});
