const request = require('supertest');
const app = require('../app');
const Driver = require('../models/Driver');

const driverData = {
  name: 'Admin Test Driver',
  email: 'driver@admintest.com',
  phone: '0771111111',
  password: 'password123',
  licenseNumber: 'LIC-ADM-01',
  vehicleNumber: 'CAR-ADM-01',
  area: 'Kandy',
};

const tripPayload = {
  startLocation: 'Kandy City',
  endLocation: 'Colombo Fort',
  distanceKm: 115,
  ratePerKm: 80,
  startTime: new Date().toISOString(),
};

// Creates a regulator directly in the DB — the register endpoint locks role to 'driver'
const createRegulatorAndLogin = async () => {
  await Driver.create({
    name: 'Regulator',
    email: 'regulator@admintest.com',
    phone: '0770000001',
    password: 'Regulator@2026!',
    licenseNumber: 'LIC-REG-01',
    vehicleNumber: 'REG-VEHICLE',
    role: 'regulator',
    isVerified: true,
  });
  const res = await request(app)
    .post('/api/auth/login')
    .send({ email: 'regulator@admintest.com', password: 'Regulator@2026!' });
  return res.body.token;
};

const registerDriver = async (data = driverData) => {
  const res = await request(app).post('/api/auth/register').send(data);
  return { token: res.body.token, driver: res.body.driver };
};

// ─── Access control ─────────────────────────────────────────────────────────

describe('Admin routes — access control', () => {
  it('returns 401 on GET /api/admin/drivers without a token', async () => {
    const res = await request(app).get('/api/admin/drivers');
    expect(res.statusCode).toBe(401);
  });

  it('returns 403 on GET /api/admin/drivers with a driver token', async () => {
    const { token } = await registerDriver();
    const res = await request(app)
      .get('/api/admin/drivers')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(403);
  });

  it('returns 401 on GET /api/admin/trips without a token', async () => {
    const res = await request(app).get('/api/admin/trips');
    expect(res.statusCode).toBe(401);
  });

  it('returns 403 on GET /api/admin/trips with a driver token', async () => {
    const { token } = await registerDriver();
    const res = await request(app)
      .get('/api/admin/trips')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(403);
  });

  it('returns 401 on PATCH /api/admin/drivers/:id/verify without a token', async () => {
    const res = await request(app)
      .patch('/api/admin/drivers/000000000000000000000000/verify')
      .send({ isVerified: true });
    expect(res.statusCode).toBe(401);
  });

  it('returns 403 on PATCH /api/admin/drivers/:id/verify with a driver token', async () => {
    const { token, driver } = await registerDriver();
    const res = await request(app)
      .patch(`/api/admin/drivers/${driver.id}/verify`)
      .set('Authorization', `Bearer ${token}`)
      .send({ isVerified: true });
    expect(res.statusCode).toBe(403);
  });
});

// ─── GET /api/admin/drivers ──────────────────────────────────────────────────

describe('GET /api/admin/drivers', () => {
  it('returns all drivers when no filter is applied', async () => {
    await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/drivers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  it('does not expose passwords in the response', async () => {
    await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/drivers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.body.every((d) => !d.password)).toBe(true);
  });

  it('returns only unverified drivers with ?verified=false', async () => {
    await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/drivers?verified=false')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.every((d) => d.isVerified === false)).toBe(true);
  });

  it('returns only verified drivers with ?verified=true', async () => {
    await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/drivers?verified=true')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.every((d) => d.isVerified === true)).toBe(true);
  });
});

// ─── PATCH /api/admin/drivers/:id/verify ────────────────────────────────────

describe('PATCH /api/admin/drivers/:id/verify', () => {
  it('approves a driver (sets isVerified to true)', async () => {
    const { driver } = await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .patch(`/api/admin/drivers/${driver.id}/verify`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isVerified: true });
    expect(res.statusCode).toBe(200);
    expect(res.body.isVerified).toBe(true);
  });

  it('rejects a driver (sets isVerified back to false)', async () => {
    const { driver } = await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    await request(app)
      .patch(`/api/admin/drivers/${driver.id}/verify`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isVerified: true });
    const res = await request(app)
      .patch(`/api/admin/drivers/${driver.id}/verify`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isVerified: false });
    expect(res.statusCode).toBe(200);
    expect(res.body.isVerified).toBe(false);
  });

  it('returns 400 when isVerified is not a boolean', async () => {
    const { driver } = await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .patch(`/api/admin/drivers/${driver.id}/verify`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isVerified: 'yes' });
    expect(res.statusCode).toBe(400);
  });

  it('returns 404 for a non-existent driver id', async () => {
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .patch('/api/admin/drivers/000000000000000000000000/verify')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isVerified: true });
    expect(res.statusCode).toBe(404);
  });
});

// ─── GET /api/admin/trips ────────────────────────────────────────────────────

describe('GET /api/admin/trips', () => {
  it('returns all trips across all drivers', async () => {
    const { token } = await registerDriver();
    await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);

    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/trips')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(1);
  });

  it('populates driver info on each trip', async () => {
    const { token } = await registerDriver();
    await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);

    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/trips')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.body[0].driver).toHaveProperty('name');
    expect(res.body[0].driver).toHaveProperty('email');
    expect(res.body[0].driver).not.toHaveProperty('password');
  });

  it('returns an empty array when there are no trips', async () => {
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/trips')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });
});

// ─── GET /api/admin/stats ────────────────────────────────────────────────────

describe('GET /api/admin/stats', () => {
  it('returns correct driver counts', async () => {
    await registerDriver();
    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('totalDrivers');
    expect(res.body).toHaveProperty('verifiedDrivers');
    expect(res.body).toHaveProperty('pendingDrivers');
    expect(res.body.totalDrivers).toBeGreaterThanOrEqual(1);
    expect(res.body.pendingDrivers).toBe(
      res.body.totalDrivers - res.body.verifiedDrivers
    );
  });

  it('includes trip and revenue stats', async () => {
    const { token } = await registerDriver();
    const createRes = await request(app)
      .post('/api/trips')
      .set('Authorization', `Bearer ${token}`)
      .send(tripPayload);
    await request(app)
      .patch(`/api/trips/${createRes.body._id}/end`)
      .set('Authorization', `Bearer ${token}`);

    const adminToken = await createRegulatorAndLogin();
    const res = await request(app)
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.totalTrips).toBeGreaterThanOrEqual(1);
    expect(res.body.completedTrips).toBeGreaterThanOrEqual(1);
    expect(res.body.totalRevenue).toBeGreaterThan(0);
  });

  it('returns 401 without a token', async () => {
    const res = await request(app).get('/api/admin/stats');
    expect(res.statusCode).toBe(401);
  });

  it('returns 403 with a driver token', async () => {
    const { token } = await registerDriver();
    const res = await request(app)
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(403);
  });
});
