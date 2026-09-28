/**
 * pricingEngine.js
 * ---------------------------------------------------------------------------
 * Surge pricing engine - mirrors the approach used by Uber / PickMe.
 *
 * Formula:
 *   effective_rate = baseRate x clamp(multiplier, min, max)
 *
 *   multiplier = weighted combination of four real-time signals:
 *     1. Demand / supply ratio  - 50% weight  (active requests vs available drivers)
 *     2. Time-of-day factor     - 25% weight  (rush hours, late-night premium)
 *     3. Weather factor         - 15% weight  (rain / storms push demand up)
 *     4. Area tier factor       - 10% weight  (Colombo > rural tier)
 *
 * The multiplier is clamped to [autoMinMultiplier, autoMaxMultiplier].
 * Weather degrades gracefully to 1.0 if the API is unreachable or unconfigured.
 */

const fetch = require('node-fetch');
const Driver = require('../models/Driver');
const RideRequest = require('../models/RideRequest');
const SystemConfig = require('../models/SystemConfig');

// --- Weather condition -> factor mapping ------------------------------------
// Source: OpenWeatherMap "weather.main" values
const WEATHER_FACTORS = {
  Thunderstorm: 1.50,
  Drizzle:      1.20,
  Rain:         1.30,
  Snow:         1.40,
  Mist:         1.10,
  Fog:          1.15,
  Haze:         1.10,
  Clear:        1.00,
  Clouds:       1.05,
};

// --- Time-of-day factor -----------------------------------------------------
function getTimeFactor(hour) {
  if (hour >= 7  && hour <= 9)  return 1.25; // morning rush
  if (hour >= 17 && hour <= 20) return 1.30; // evening rush
  if (hour >= 22 || hour <= 2)  return 1.20; // late-night
  return 1.00;
}

// --- Demand/supply ratio -> factor ------------------------------------------
function getDemandSupplyFactor(activeRequests, availableDrivers) {
  const ratio = activeRequests / Math.max(availableDrivers, 1);
  if (ratio <= 1.0) return 1.00;
  if (ratio <= 1.5) return 1.15;
  if (ratio <= 2.0) return 1.35;
  if (ratio <= 2.5) return 1.55;
  return 1.75;
}

// --- Weather fetch ----------------------------------------------------------
async function fetchWeatherFactor(area) {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey || apiKey === 'your-openweather-api-key') {
    return { factor: 1.0, condition: 'Unknown' };
  }
  try {
    const city = encodeURIComponent(area + ',LK');
    const url  = `https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${apiKey}`;
    const res  = await fetch(url, { timeout: 5000 });
    if (!res.ok) return { factor: 1.0, condition: 'Unknown' };
    const data      = await res.json();
    const condition = data?.weather?.[0]?.main ?? 'Clear';
    return { factor: WEATHER_FACTORS[condition] ?? 1.0, condition };
  } catch {
    return { factor: 1.0, condition: 'Unknown' };
  }
}

// --- Main export ------------------------------------------------------------
/**
 * computeAutoRate(area)
 * Returns { effectiveRate, baseRate, multiplier, breakdown }
 */
async function computeAutoRate(area = '') {
  let config = await SystemConfig.findOne();
  if (!config) config = await SystemConfig.create({});

  const baseRate = config.autoBaseRate        ?? 100;
  const minM     = config.autoMinMultiplier   ?? 1.0;
  const maxM     = config.autoMaxMultiplier   ?? 2.5;

  // Area tier factor: case-insensitive lookup, default 1.0 for unlisted areas
  const factorsMap = config.autoAreaFactors?.toObject?.() ?? {};
  const areaKey    = Object.keys(factorsMap).find(
    (k) => k.toLowerCase() === (area || '').toLowerCase()
  );
  const areaFactor = areaKey ? (factorsMap[areaKey] ?? 1.0) : 1.0;

  // Demand / supply counts
  const areaFilter = area
    ? { $regex: new RegExp('^' + area + '$', 'i') }
    : { $exists: true };

  const [availableDrivers, activeRequests] = await Promise.all([
    Driver.countDocuments({ area: areaFilter, isVerified: true }),
    RideRequest.countDocuments({ isActive: true }),
  ]);
  const demandSupplyFactor = getDemandSupplyFactor(activeRequests, availableDrivers);

  // Time of day
  const timeFactor = getTimeFactor(new Date().getHours());

  // Weather
  const { factor: weatherFactor, condition: weatherCondition } =
    await fetchWeatherFactor(area || 'Colombo');

  // Weighted combination (weights: 0.50 + 0.25 + 0.15 + 0.10 = 1.00)
  const rawMultiplier =
    demandSupplyFactor * 0.50 +
    timeFactor         * 0.25 +
    weatherFactor      * 0.15 +
    areaFactor         * 0.10;

  const multiplier    = parseFloat(Math.min(maxM, Math.max(minM, rawMultiplier)).toFixed(2));
  const effectiveRate = parseFloat((baseRate * multiplier).toFixed(2));

  return {
    effectiveRate,
    baseRate,
    multiplier,
    breakdown: {
      demandSupplyFactor: parseFloat(demandSupplyFactor.toFixed(2)),
      timeFactor:         parseFloat(timeFactor.toFixed(2)),
      weatherFactor:      parseFloat(weatherFactor.toFixed(2)),
      areaFactor:         parseFloat(areaFactor.toFixed(2)),
      weatherCondition,
      activeRequests,
      availableDrivers,
    },
  };
}

module.exports = { computeAutoRate };
