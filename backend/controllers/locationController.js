const GOOGLE_PLACES_BASE_URL = 'https://places.googleapis.com/v1';
const GOOGLE_GEOCODING_URL = 'https://maps.googleapis.com/maps/api/geocode/json';
const GOOGLE_ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const REQUEST_TIMEOUT_MS = 8000;

const getApiKey = () => String(process.env.GOOGLE_MAPS_API_KEY || '').trim();

const describeGooglePlacesError = (data, status) => {
  const message = data?.error?.message || data?.message || 'Google Places request failed';
  const statusCode = data?.error?.status || data?.status;

  if (status === 403 || statusCode === 'PERMISSION_DENIED' || /key|permission|forbidden/i.test(message)) {
    return 'Google Maps API key is invalid or does not have Places API access.';
  }

  if (status === 429 || /quota|rate limit/i.test(message)) {
    return 'Google Maps Places quota has been exceeded. Please try again later.';
  }

  if (status === 400 || /invalid|bad request/i.test(message)) {
    return 'Google Maps Places request was rejected. Please try again with a different search term.';
  }

  return 'Location search is temporarily unavailable. Please try again in a moment.';
};

const fetchGooglePlaces = async (url, options) => {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('[Google API Error]', response.status, JSON.stringify(data, null, 2));
    const error = new Error(describeGooglePlacesError(data, response.status));
    error.status = response.status;
    error.details = data;
    throw error;
  }
  return data;
};

const describeGoogleRoutesError = (data, status) => {
  const message = data?.error?.message || data?.message || 'Google Routes request failed';
  const statusCode = data?.error?.status || data?.status;

  if (status === 403 || statusCode === 'PERMISSION_DENIED' || /key|permission|forbidden/i.test(message)) {
    return 'Google Maps API key is invalid or does not have Routes API access.';
  }

  if (status === 429 || /quota|rate limit/i.test(message)) {
    return 'Google Maps Routes quota has been exceeded. Please try again later.';
  }

  if (status === 400 || /invalid|bad request/i.test(message)) {
    return 'Google Maps could not calculate a route for these locations.';
  }

  return 'Road route is temporarily unavailable. Please try again in a moment.';
};

const fetchGoogleRoute = async (options) => {
  const response = await fetch(GOOGLE_ROUTES_URL, {
    ...options,
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('[Google Routes Error]', response.status, JSON.stringify(data, null, 2));
    const error = new Error(describeGoogleRoutesError(data, response.status));
    error.status = response.status;
    error.details = data;
    throw error;
  }
  return data;
};

const autocompletePlaces = async (req, res) => {
  const apiKey = getApiKey();
  if (!apiKey) {
    return res.status(503).json({
      message: 'Location search is not configured. Set GOOGLE_MAPS_API_KEY on the backend.',
    });
  }

  const input = String(req.query.input || '').trim();
  if (input.length < 2 || input.length > 200) {
    return res.status(400).json({ message: 'Search input must be between 2 and 200 characters' });
  }

  const sessionToken = String(req.query.sessionToken || '').trim();
  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lng);
  const hasBias = Number.isFinite(latitude) && Number.isFinite(longitude)
    && latitude >= -90 && latitude <= 90
    && longitude >= -180 && longitude <= 180;

  const body = {
    input,
    includedRegionCodes: ['lk'],
    languageCode: 'en',
    regionCode: 'lk',
    ...(sessionToken ? { sessionToken } : {}),
    ...(hasBias
      ? {
          origin: { latitude, longitude },
          locationBias: {
            circle: {
              center: { latitude, longitude },
              radius: 50000,
            },
          },
        }
      : {}),
  };

  try {
    const data = await fetchGooglePlaces(`${GOOGLE_PLACES_BASE_URL}/places:autocomplete`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': [
          'suggestions.placePrediction.placeId',
          'suggestions.placePrediction.text.text',
          'suggestions.placePrediction.structuredFormat.mainText.text',
          'suggestions.placePrediction.structuredFormat.secondaryText.text',
          'suggestions.placePrediction.distanceMeters',
        ].join(','),
      },
      body: JSON.stringify(body),
    });

    let suggestions = (data.suggestions || [])
      .map((item) => item.placePrediction)
      .filter((prediction) => prediction?.placeId && prediction?.text?.text)
      .map((prediction) => ({
        placeId: prediction.placeId,
        description: prediction.text.text,
        mainText: prediction.structuredFormat?.mainText?.text || prediction.text.text,
        secondaryText: prediction.structuredFormat?.secondaryText?.text || 'Sri Lanka',
        distanceMeters: Number.isFinite(prediction.distanceMeters)
          ? prediction.distanceMeters
          : null,
      }));

    // Autocomplete is ideal while typing, but a fuzzy business, landmark, road,
    // or building name can occasionally produce no prediction. Text Search is
    // the Google-recommended fallback for these free-form queries.
    if (suggestions.length === 0 && input.length >= 3) {
      const searchBody = {
        textQuery: input,
        pageSize: 8,
        languageCode: 'en',
        regionCode: 'lk',
        ...(hasBias
          ? {
              locationBias: {
                circle: {
                  center: { latitude, longitude },
                  radius: 50000,
                },
              },
            }
          : {}),
      };
      const searchData = await fetchGooglePlaces(
        `${GOOGLE_PLACES_BASE_URL}/places:searchText`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': [
              'places.id',
              'places.displayName',
              'places.formattedAddress',
              'places.location',
            ].join(','),
          },
          body: JSON.stringify(searchBody),
        },
      );

      suggestions = (searchData.places || [])
        .filter((place) => place?.id && place?.displayName?.text)
        .map((place) => ({
          placeId: place.id,
          description: place.formattedAddress || place.displayName.text,
          mainText: place.displayName.text,
          secondaryText: place.formattedAddress || 'Sri Lanka',
          lat: Number.isFinite(place.location?.latitude)
            ? place.location.latitude
            : null,
          lng: Number.isFinite(place.location?.longitude)
            ? place.location.longitude
            : null,
          distanceMeters: null,
        }));
    }

    res.set('Cache-Control', 'no-store');
    return res.json({ suggestions });
  } catch (error) {
    const status = error.name === 'TimeoutError' ? 504 : 502;
    const message = error.message || 'Location search is temporarily unavailable';
    const httpStatus = error.status === 403 ? 503 : status;
    return res.status(httpStatus).json({ message });
  }
};

const getPlaceDetails = async (req, res) => {
  const apiKey = getApiKey();
  if (!apiKey) {
    return res.status(503).json({
      message: 'Location search is not configured. Set GOOGLE_MAPS_API_KEY on the backend.',
    });
  }

  const placeId = String(req.params.placeId || '').trim();
  if (!placeId || placeId.length > 300) {
    return res.status(400).json({ message: 'Valid placeId is required' });
  }

  const sessionToken = String(req.query.sessionToken || '').trim();
  const query = sessionToken ? `?sessionToken=${encodeURIComponent(sessionToken)}` : '';

  try {
    const place = await fetchGooglePlaces(
      `${GOOGLE_PLACES_BASE_URL}/places/${encodeURIComponent(placeId)}${query}`,
      {
        method: 'GET',
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
        },
      },
    );

    if (!Number.isFinite(place.location?.latitude) || !Number.isFinite(place.location?.longitude)) {
      return res.status(502).json({ message: 'Selected place has no map coordinates' });
    }

    res.set('Cache-Control', 'no-store');
    return res.json({
      placeId: place.id || placeId,
      name: place.displayName?.text || place.formattedAddress || 'Selected location',
      address: place.formattedAddress || place.displayName?.text || 'Selected location',
      lat: place.location.latitude,
      lng: place.location.longitude,
    });
  } catch (error) {
    const status = error.name === 'TimeoutError' ? 504 : 502;
    const message = error.message || 'Could not load the selected location';
    const httpStatus = error.status === 403 ? 503 : status;
    return res.status(httpStatus).json({ message });
  }
};

const reverseGeocode = async (req, res) => {
  const apiKey = getApiKey();
  if (!apiKey) {
    return res.status(503).json({
      message: 'Location lookup is not configured. Set GOOGLE_MAPS_API_KEY on the backend.',
    });
  }

  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lng);
  const validCoordinates = Number.isFinite(latitude) && Number.isFinite(longitude)
    && latitude >= -90 && latitude <= 90
    && longitude >= -180 && longitude <= 180;
  if (!validCoordinates) {
    return res.status(400).json({ message: 'Valid latitude and longitude are required' });
  }

  try {
    const url = new URL(GOOGLE_GEOCODING_URL);
    url.searchParams.set('latlng', `${latitude},${longitude}`);
    url.searchParams.set('language', 'en');
    url.searchParams.set('region', 'lk');
    url.searchParams.set('key', apiKey);
    const data = await fetchGooglePlaces(url.toString(), { method: 'GET' });
    const result = (data.results || []).find((item) => item?.formatted_address);
    if (!result) {
      return res.status(404).json({ message: 'No address found for this location' });
    }
    res.set('Cache-Control', 'private, max-age=300');
    return res.json({
      address: result.formatted_address,
      placeId: result.place_id || null,
      lat: latitude,
      lng: longitude,
    });
  } catch (error) {
    const status = error.name === 'TimeoutError' ? 504 : 502;
    const message = error.message || 'Could not identify the live location';
    const httpStatus = error.status === 403 ? 503 : status;
    return res.status(httpStatus).json({ message });
  }
};

const getDrivingRoute = async (req, res) => {
  const apiKey = getApiKey();
  if (!apiKey) {
    return res.status(503).json({
      message: 'Road routing is not configured. Set GOOGLE_MAPS_API_KEY on the backend.',
    });
  }

  const pickupLat = Number(req.body?.pickupLat);
  const pickupLng = Number(req.body?.pickupLng);
  const destinationLat = Number(req.body?.destinationLat);
  const destinationLng = Number(req.body?.destinationLng);
  const validCoordinates = [
    [pickupLat, -90, 90],
    [pickupLng, -180, 180],
    [destinationLat, -90, 90],
    [destinationLng, -180, 180],
  ].every(([value, minimum, maximum]) => (
    Number.isFinite(value) && value >= minimum && value <= maximum
  ));

  if (!validCoordinates) {
    return res.status(400).json({
      message: 'Valid pickup and destination coordinates are required',
    });
  }

  try {
    const data = await fetchGoogleRoute({
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': [
          'routes.distanceMeters',
          'routes.duration',
          'routes.polyline.encodedPolyline',
        ].join(','),
      },
      body: JSON.stringify({
        origin: {
          location: {
            latLng: { latitude: pickupLat, longitude: pickupLng },
          },
        },
        destination: {
          location: {
            latLng: { latitude: destinationLat, longitude: destinationLng },
          },
        },
        travelMode: 'DRIVE',
        routingPreference: 'TRAFFIC_AWARE',
        polylineQuality: 'OVERVIEW',
        polylineEncoding: 'ENCODED_POLYLINE',
        languageCode: 'en-US',
        units: 'METRIC',
      }),
    });

    const route = Array.isArray(data.routes) ? data.routes[0] : null;
    const encodedPolyline = route?.polyline?.encodedPolyline;
    if (!encodedPolyline) {
      return res.status(404).json({
        message: 'No drivable route was found between these locations.',
      });
    }

    res.set('Cache-Control', 'no-store');
    return res.json({
      encodedPolyline,
      distanceMeters: Number.isFinite(route.distanceMeters)
        ? route.distanceMeters
        : null,
      duration: route.duration || null,
    });
  } catch (error) {
    const status = error.name === 'TimeoutError' ? 504 : 502;
    const message = error.message || 'Could not calculate the road route';
    const httpStatus = error.status === 403 ? 503 : status;
    return res.status(httpStatus).json({ message });
  }
};

module.exports = {
  autocompletePlaces,
  getPlaceDetails,
  reverseGeocode,
  getDrivingRoute,
};
