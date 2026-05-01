const request = require('supertest');
const app = require('../app');
const validDriver = {
  name: 'Test Driver',
  email: 'driver@test.com',
  phone: '0771234567',
  password: 'password123',
  licenseNumber: 'LIC-001',
  vehicleNumber: 'CAR-001',
  area: 'Colombo',
};

// Helper: register a driver and return the auth token
const registerAndLogin = async (data = validDriver) => {
  const res = await request(app).post('/api/auth/register').send(data);
  return res.body.token;
};

describe('GET /api/drivers/profile', () => {
  it('returns driver profile when authenticated', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .get('/api/drivers/profile')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ name: 'Test Driver', email: 'driver@test.com' });
    expect(res.body).not.toHaveProperty('password');
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).get('/api/drivers/profile');
    expect(res.statusCode).toBe(401);
  });

  it('returns 401 with an invalid token', async () => {
    const res = await request(app)
      .get('/api/drivers/profile')
      .set('Authorization', 'Bearer invalidtoken');
    expect(res.statusCode).toBe(401);
  });
});

describe('POST /api/drivers/generate-qr', () => {
  it('generates and returns a QR code', async () => {
    const token = await registerAndLogin();
    const res = await request(app)
      .post('/api/drivers/generate-qr')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('qrCode');
    expect(res.body.qrCode).toMatch(/^data:image\/png;base64,/);
  });
});

describe('GET /api/drivers/nearby', () => {
  it('returns verified drivers in a given area', async () => {
    const res = await request(app).get('/api/drivers/nearby?area=Colombo');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
