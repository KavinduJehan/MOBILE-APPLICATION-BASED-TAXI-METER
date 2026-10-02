const jwt = require('jsonwebtoken');
const request = require('supertest');
const app = require('../app');

const customerToken = () => jwt.sign(
  { id: '000000000000000000000001', role: 'customer', name: 'Test Customer' },
  process.env.JWT_SECRET,
  { expiresIn: '1h' },
);

const driverToken = () => jwt.sign(
  { id: '000000000000000000000002', role: 'driver', name: 'Test Driver' },
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

  it('surfaces Google Places permission issues clearly', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: async () => ({
        error: {
          code: 403,
          message: 'The provided API key is invalid. Please check your key and try again.',
          status: 'PERMISSION_DENIED',
        },
      }),
    });

    const res = await request(app)
      .get('/api/locations/autocomplete?input=Galle')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(503);
    expect(res.body.message).toContain('Google Maps API key');
    expect(res.body.message).toContain('Places API');
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
        distanceMeters: null,
      },
    ]);
    const requestBody = JSON.parse(global.fetch.mock.calls[0][1].body);
    expect(requestBody.includedRegionCodes).toEqual(['lk']);
    expect(requestBody.origin).toEqual({ latitude: 6.9, longitude: 79.8 });
    expect(requestBody.locationBias.circle.center).toEqual({
      latitude: 6.9,
      longitude: 79.8,
    });
  });

  it('falls back to text search for roads, businesses, and landmarks', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [] }),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          places: [
            {
              id: 'shop-1',
              displayName: { text: 'Green Cabin' },
              formattedAddress: 'Galle Road, Colombo 03, Sri Lanka',
              location: { latitude: 6.9001, longitude: 79.8532 },
            },
          ],
        }),
      });

    const res = await request(app)
      .get('/api/locations/autocomplete?input=Green%20Cabin&lat=6.9&lng=79.8')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(200);
    expect(global.fetch).toHaveBeenCalledTimes(2);
    expect(global.fetch.mock.calls[1][0]).toContain('/places:searchText');
    expect(res.body.suggestions[0]).toMatchObject({
      placeId: 'shop-1',
      mainText: 'Green Cabin',
      secondaryText: 'Galle Road, Colombo 03, Sri Lanka',
      lat: 6.9001,
      lng: 79.8532,
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

  it('returns a human-readable address for live coordinates', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 'OK',
        results: [
          {
            formatted_address: '22 Nawala Road, Nawala, Sri Lanka',
            place_id: 'live-place-1',
          },
        ],
      }),
    });

    const res = await request(app)
      .get('/api/locations/reverse?lat=6.89&lng=79.88')
      .set('Authorization', `Bearer ${customerToken()}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({
      address: '22 Nawala Road, Nawala, Sri Lanka',
      placeId: 'live-place-1',
      lat: 6.89,
      lng: 79.88,
    });
    const requestUrl = new URL(global.fetch.mock.calls[0][0]);
    expect(requestUrl.searchParams.get('latlng')).toBe('6.89,79.88');
    expect(requestUrl.searchParams.get('region')).toBe('lk');
  });

  it('returns an encoded driving route between selected locations', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        routes: [
          {
            distanceMeters: 12500,
            duration: '1800s',
            polyline: { encodedPolyline: 'route-polyline' },
          },
        ],
      }),
    });

    const res = await request(app)
      .post('/api/locations/route')
      .set('Authorization', 'Bearer ' + customerToken())
      .send({
        pickupLat: 6.9271,
        pickupLng: 79.8612,
        destinationLat: 6.0329,
        destinationLng: 80.2168,
      });

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      encodedPolyline: 'route-polyline',
      distanceMeters: 12500,
      duration: '1800s',
    });
    expect(global.fetch.mock.calls[0][0]).toContain(
      'routes.googleapis.com/directions/v2:computeRoutes',
    );
    const options = global.fetch.mock.calls[0][1];
    expect(options.headers['X-Goog-FieldMask']).toContain(
      'routes.polyline.encodedPolyline',
    );
    expect(JSON.parse(options.body)).toMatchObject({
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_AWARE',
    });
  });

  it('lets drivers fetch a road route to the pickup', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        routes: [
          {
            distanceMeters: 2300,
            duration: '420s',
            polyline: { encodedPolyline: 'driver-polyline' },
          },
        ],
      }),
    });

    const res = await request(app)
      .post('/api/locations/route')
      .set('Authorization', 'Bearer ' + driverToken())
      .send({
        pickupLat: 6.9271,
        pickupLng: 79.8612,
        destinationLat: 6.9147,
        destinationLng: 79.8737,
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.encodedPolyline).toBe('driver-polyline');
    expect(JSON.parse(global.fetch.mock.calls[0][1].body).polylineQuality)
      .toBe('HIGH_QUALITY');
  });

  it('rejects invalid route coordinates before calling Google', async () => {
    process.env.GOOGLE_MAPS_API_KEY = 'test-key';
    global.fetch = jest.fn();

    const res = await request(app)
      .post('/api/locations/route')
      .set('Authorization', 'Bearer ' + customerToken())
      .send({
        pickupLat: 200,
        pickupLng: 79.8612,
        destinationLat: 6.0329,
        destinationLng: 80.2168,
      });

    expect(res.statusCode).toBe(400);
    expect(global.fetch).not.toHaveBeenCalled();
  });
});
