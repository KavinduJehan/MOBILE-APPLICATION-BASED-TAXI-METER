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

describe('POST /api/auth/register', () => {
  it('registers a new driver and returns a token', async () => {
    const res = await request(app).post('/api/auth/register').send(validDriver);
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body.driver).toMatchObject({ name: 'Test Driver', email: 'driver@test.com' });
  });

  it('returns 409 if email is already registered', async () => {
    await request(app).post('/api/auth/register').send(validDriver);
    const res = await request(app).post('/api/auth/register').send(validDriver);
    expect(res.statusCode).toBe(409);
  });

  it('returns 400 if required fields are missing', async () => {
    const res = await request(app).post('/api/auth/register').send({ email: 'x@x.com' });
    expect(res.statusCode).toBe(400);
  });
});

describe('POST /api/auth/login', () => {
  beforeEach(async () => {
    await request(app).post('/api/auth/register').send(validDriver);
  });

  it('logs in with correct credentials and returns a token', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: validDriver.email, password: validDriver.password });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  it('returns 401 with wrong password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: validDriver.email, password: 'wrongpass' });
    expect(res.statusCode).toBe(401);
  });

  it('returns 401 with unknown email', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'unknown@test.com', password: 'password123' });
    expect(res.statusCode).toBe(401);
  });

  it('returns 400 if email or password is missing', async () => {
    const res = await request(app).post('/api/auth/login').send({ email: validDriver.email });
    expect(res.statusCode).toBe(400);
  });
});
