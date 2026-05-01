const request = require('supertest');
const app = require('../app');
const validDriver = {
  name: 'Trip Driver',
  email: 'trip@test.com',
  phone: '0770001111',
  password: 'password123',
  licenseNumber: 'LIC-TRIP',
  vehicleNumber: 'CAR-TRIP',
  area: 'Matara',
};

const tripPayload = {
  startLocation: 'Matara Bus Stand',
  endLocation: 'Galle Fort',
  distanceKm: 38,
  ratePerKm: 75,
  customerName: 'Nimal Perera',
  startTime: new Date().toISOString(),
};

const registerAndLogin = async (data = validDriver) => {
  const res = await request(app).post('/api/auth/register').send(data);
  return res.body.token;
};

describe('POST /api/trips', () => {
  it('creates a trip and calculates total fare', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);
    expect(res.statusCode).toBe(201);
    expect(res.body.totalFare).toBe(38 * 75);
    expect(res.body.status).toBe('ongoing');
  });

  it('returns 400 when required fields are missing', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send({ startLocation: 'Matara' }); // missing endLocation, distanceKm, ratePerKm
    expect(res.statusCode).toBe(400);
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).post('/api/trips').send(tripPayload);
    expect(res.statusCode).toBe(401);
  });
});

describe('PATCH /api/trips/:id/end', () => {
  it('ends a trip and generates a receipt', async () => {
    const token = await registerAndLogin();
    const createRes = await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);
    const tripId = createRes.body._id;

    const endRes = await request(app)
      .patch(`/api/trips/${tripId}/end`)
      .set('Authorization', `Bearer ${token}`);
    expect(endRes.statusCode).toBe(200);
    expect(endRes.body.trip.status).toBe('completed');
    expect(endRes.body.receipt).toHaveProperty('receiptNumber');
    expect(endRes.body.receipt.totalFare).toBe(38 * 75);
  });

  it('returns 404 for a non-existent trip', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .patch('/api/trips/000000000000000000000000/end')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(404);
  });
});

describe('GET /api/trips/my', () => {
  it('returns only the logged-in driver\'s trips', async () => {
    const token = await registerAndLogin();
    await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);

    const res = await request(app)
      .get('/api/trips/my')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(1);
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).get('/api/trips/my');
    expect(res.statusCode).toBe(401);
  });
});
