require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const apiKey = String(process.env.GOOGLE_MAPS_API_KEY || '').trim();

console.log('Testing Google Maps API Key...');
console.log('Key length:', apiKey.length);
console.log('Key preview:', apiKey.substring(0, 8) + '...' + apiKey.substring(apiKey.length - 4));

if (!apiKey) {
  console.error('ERROR: No GOOGLE_MAPS_API_KEY found in backend/.env');
  process.exit(1);
}

async function testKey() {
  const url = 'https://places.googleapis.com/v1/places:autocomplete';
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
      },
      body: JSON.stringify({
        input: 'Colombo',
      }),
    });

    const data = await response.json();
    console.log('\n--- Autocomplete HTTP Status ---:', response.status);
    
    if (data.suggestions && data.suggestions.length > 0) {
      const placeId = data.suggestions[0].placePrediction.placeId;
      console.log('\nTesting Place Details for placeId:', placeId);
      const detailsUrl = `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`;
      const detailsRes = await fetch(detailsUrl, {
        method: 'GET',
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
        },
      });
      const detailsData = await detailsRes.json();
      console.log('--- Place Details HTTP Status ---:', detailsRes.status);
      console.log('--- Place Details Response ---:');
      console.log(JSON.stringify(detailsData, null, 2));
    }
  } catch (err) {
    console.error('Network/Fetch error:', err.message, err.cause || '');
  }
}

testKey();
