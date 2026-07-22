const GOOGLE_PLACES_BASE_URL = 'https://places.googleapis.com/v1';
const REQUEST_TIMEOUT_MS = 8000;

const getApiKey = () => String(process.env.GOOGLE_MAPS_API_KEY || '').trim();

const fetchGooglePlaces = async (url, options) => {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data?.error?.message || 'Google Places request failed');
    error.status = response.status;
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
        ].join(','),
      },
      body: JSON.stringify(body),
    });

    const suggestions = (data.suggestions || [])
      .map((item) => item.placePrediction)
      .filter((prediction) => prediction?.placeId && prediction?.text?.text)
      .map((prediction) => ({
        placeId: prediction.placeId,
        description: prediction.text.text,
        mainText: prediction.structuredFormat?.mainText?.text || prediction.text.text,
        secondaryText: prediction.structuredFormat?.secondaryText?.text || 'Sri Lanka',
      }));

    res.set('Cache-Control', 'no-store');
    return res.json({ suggestions });
  } catch (error) {
    const status = error.name === 'TimeoutError' ? 504 : 502;
    return res.status(status).json({ message: 'Location search is temporarily unavailable' });
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
    return res.status(status).json({ message: 'Could not load the selected location' });
  }
};

module.exports = { autocompletePlaces, getPlaceDetails };
