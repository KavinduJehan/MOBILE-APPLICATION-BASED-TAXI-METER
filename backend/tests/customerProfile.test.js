const jwt = require('jsonwebtoken');
const request = require('supertest');

const app = require('../app');
const Customer = require('../models/Customer');

const createCustomerSession = async () => {
  const customer = await Customer.create({
    name: 'Profile Customer',
    email: 'profile.customer@example.com',
    phone: '0771234567',
  });
  const token = jwt.sign(
    {
      id: customer._id,
      name: customer.name,
      phone: customer.phone,
      role: 'customer',
    },
    process.env.JWT_SECRET,
    { expiresIn: '1h' }
  );
  return { customer, token };
};

describe('PATCH /api/customers/profile', () => {
  it('validates and persists a customer profile image', async () => {
    const { customer, token } = await createCustomerSession();
    const jpegBytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
    const profileImage =
      'data:image/jpeg;base64,' + jpegBytes.toString('base64');

    const response = await request(app)
      .patch('/api/customers/profile')
      .set('Authorization', 'Bearer ' + token)
      .send({
        name: 'Updated Customer',
        email: 'updated.customer@example.com',
        phone: '0771234567',
        birthday: '',
        gender: '',
        profileImage,
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.customer.profileImage).toBe(profileImage);

    const stored = await Customer.findById(customer._id);
    expect(stored.profileImage).toBe(profileImage);
    expect(stored.name).toBe('Updated Customer');
  });

  it('rejects content that is not a real supported image', async () => {
    const { token } = await createCustomerSession();
    const fakeImage =
      'data:image/jpeg;base64,' +
      Buffer.from('not an image').toString('base64');

    const response = await request(app)
      .patch('/api/customers/profile')
      .set('Authorization', 'Bearer ' + token)
      .send({
        name: 'Profile Customer',
        email: 'profile.customer@example.com',
        phone: '0771234567',
        birthday: '',
        gender: '',
        profileImage: fakeImage,
      });

    expect(response.statusCode).toBe(400);
  });
});
