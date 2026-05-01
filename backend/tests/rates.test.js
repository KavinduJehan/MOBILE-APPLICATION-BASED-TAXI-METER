const request = require('supertest');
const app = require('../app');
const Driver = require('../models/Driver');
const validDriver = {
  name: 'Rate Driver',
  email: 'rate@test.com',
  phone: '0779876543',
  password: 'password123',
  licenseNumber: 'LIC-RATE',
  vehicleNumber: 'CAR-RATE',
  area: 'Galle',
};

const registerAndLogin = async (data = validDriver) => {
  const res = await request(app).post('/api/auth/register').send(data);
  return res.body.token;
};

describe('PATCH /api/rates/my-rate', () => {
  it('updates the driver rate successfully', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .patch('/api/rates/my-rate')
      .set('Authorization', `Bearer ${token}`)
      .send({ ratePerKm: 85 });
    expect(res.statusCode).toBe(200);
    expect(res.body.ratePerKm).toBe(85);
  });

  it('returns 400 for a negative rate', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .patch('/api/rates/my-rate')
      .set('Authorization', `Bearer ${token}`)
      .send({ ratePerKm: -5 });
    expect(res.statusCode).toBe(400);
  });

  it('returns 400 when ratePerKm is missing', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .patch('/api/rates/my-rate')
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(res.statusCode).toBe(400);
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).patch('/api/rates/my-rate').send({ ratePerKm: 85 });
    expect(res.statusCode).toBe(401);
  });
});

describe('GET /api/rates/area', () => {
  it('returns average rate and driver list for an area', async () => {
    const token = await registerAndLogin();
    await request(app)
      .patch('/api/rates/my-rate')
      .set('Authorization', `Bearer ${token}`)
      .send({ ratePerKm: 90 });

    const res = await request(app).get('/api/rates/area?area=Galle');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('area', 'Galle');
    // Driver is not verified so average may be null — just confirm shape
    expect(res.body).toHaveProperty('averageRate');
    expect(Array.isArray(res.body.drivers)).toBe(true);
  });

  it('does not include unverified drivers in the area rate results', async () => {
    await registerAndLogin(); // registers but isVerified stays false
    const res = await request(app).get('/api/rates/area?area=Galle');
    expect(res.statusCode).toBe(200);
    expect(res.body.drivers).toEqual([]);
    expect(res.body.averageRate).toBeNull();
  });

  it('includes verified drivers in the area rate results', async () => {
    const token = await registerAndLogin();
    await request(app)
      .patch('/api/rates/my-rate')
      .set('Authorization', `Bearer ${token}`)
      .send({ ratePerKm: 90 });

    // Verify the driver directly via the model (as an admin would via the API)
    await Driver.findOneAndUpdate({ email: validDriver.email }, { isVerified: true });

    const res = await request(app).get('/api/rates/area?area=Galle');
    expect(res.statusCode).toBe(200);
    expect(res.body.drivers.length).toBe(1);
    expect(res.body.averageRate).toBe(90);
  });

  it('returns 400 when area query param is missing', async () => {
    const res = await request(app).get('/api/rates/area');
    expect(res.statusCode).toBe(400);
  });
});
