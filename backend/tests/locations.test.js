const jwt = require('jsonwebtoken');
const request = require('supertest');
const app = require('../app');

const customerToken = () => jwt.sign(
  { id: '000000000000000000000001', role: 'customer', name: 'Test Customer' },
  process.env.JWT_SECRET,
  { expiresIn: '1h' },
);

describe('Google Places proxy', () => {
  const originalApiKey = process.env.GOOGLE_MAPS_API_KEY;
  const originalFetch = global.fetch;

  afterEach(() => {
    if (originalApiKey == null) {
      delete process.env.GOOGLE_MAPS_API_KEY;
    } else {
      process.env.GOOGLE_MAPS_API_KEY = originalApiKey;
    }
    global.fetch = originalFetch;
  });

  it('requires customer authentication', async () => {
    const res = await request(app).get('/api/locations/autocomplete?input=Galle');
    expect(res.statusCode).toBe(401);
  });

  it('returns a clear error when the API key is missing', async () => {
    delete process.env.GOOGLE_MAPS_API_KEY;
    const res = await request(app)
      .get('/api/locations/autocomplete?input=Galle')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(503);
    expect(res.body.message).toContain('GOOGLE_MAPS_API_KEY');
  });

  it('normalizes Sri Lankan autocomplete predictions', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        suggestions: [
          {
            placePrediction: {
              placeId: 'place-1',
              text: { text: 'Galle Road, Colombo, Sri Lanka' },
              structuredFormat: {
                mainText: { text: 'Galle Road' },
                secondaryText: { text: 'Colombo, Sri Lanka' },
              },
            },
          },
        ],
      }),
    });

    const res = await request(app)
      .get('/api/locations/autocomplete?input=Galle%20Road&lat=6.9&lng=79.8&sessionToken=session-1')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.suggestions).toEqual([
      {
        placeId: 'place-1',
        description: 'Galle Road, Colombo, Sri Lanka',
        mainText: 'Galle Road',
        secondaryText: 'Colombo, Sri Lanka',
      },
    ]);
    const requestBody = JSON.parse(global.fetch.mock.calls[0][1].body);
    expect(requestBody.includedRegionCodes).toEqual(['lk']);
    expect(requestBody.locationBias.circle.center).toEqual({
      latitude: 6.9,
      longitude: 79.8,
    });
  });

  it('returns coordinates for a selected place', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        id: 'place-1',
        displayName: { text: 'Galle Road' },
        formattedAddress: 'Galle Road, Colombo, Sri Lanka',
        location: { latitude: 6.891, longitude: 79.856 },
      }),
    });

    const res = await request(app)
      .get('/api/locations/details/place-1?sessionToken=session-1')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({
      placeId: 'place-1',
      name: 'Galle Road',
      address: 'Galle Road, Colombo, Sri Lanka',
      lat: 6.891,
      lng: 79.856,
    });
  });
});
