/**
 * pricingEngine.js
 * ---------------------------------------------------------------------------
 * Surge pricing engine - mirrors the approach used by Uber / PickMe.
 *
 * Formula:
 *   effective_rate = baseRate x clamp(multiplier, min, max)
 *
 *   multiplier = weighted combination of four real-time signals:
 *     1. Demand / supply ratio  - 50% weight  (active requests vs available drivers nearby)
 *     2. Time-of-day factor     - 25% weight  (rush hours, late-night premium)
 *     3. Weather factor         - 15% weight  (rain / storms push demand up)
 *     4. Area tier factor       - 10% weight  (city hub vs rural tier)
 *
 * Coordinate mode (preferred):
 *   Pass { lat, lng } — weather is queried by exact GPS, demand/supply is counted within a
 *   radius around the pickup point, and the area tier is resolved via virtual geofences
 *   (no manual city-name entry needed).
 *
 * Fallback mode (backward compat):
 *   Pass { area } string — used by admin API preview, legacy callers, and tests.
 *
 * The multiplier is clamped to [autoMinMultiplier, autoMaxMultiplier].
 * Weather degrades gracefully to 1.0 if the API is unreachable or unconfigured.
 */

const fetch = require('node-fetch');
const Driver = require('../models/Driver');
const RideRequest = require('../models/RideRequest');
const SystemConfig = require('../models/SystemConfig');

// ---------------------------------------------------------------------------
// Geofence hubs — virtual circular zones for automatic area tier detection.
// Defined as { name, lat, lng, radiusKm, factor }.
// Tiers: A = major cities (1.15), B = moderate cities (1.05), C = rural (1.00)
// ---------------------------------------------------------------------------
const GEOFENCE_HUBS = [
  // Tier A — high demand / commercial hubs
  { name: 'Colombo',      lat: 6.9271,  lng: 79.8612, radiusKm: 25, factor: 1.15 },
  { name: 'Kandy',        lat: 7.2906,  lng: 80.6337, radiusKm: 15, factor: 1.15 },
  { name: 'Galle',        lat: 6.0535,  lng: 80.2210, radiusKm: 15, factor: 1.15 },
  // Tier B — moderate urban centres
  { name: 'Negombo',      lat: 7.2088,  lng: 79.8358, radiusKm: 12, factor: 1.05 },
  { name: 'Kurunegala',   lat: 7.4867,  lng: 80.3647, radiusKm: 12, factor: 1.05 },
  { name: 'Ratnapura',    lat: 6.6828,  lng: 80.4000, radiusKm: 12, factor: 1.05 },
  { name: 'Jaffna',       lat: 9.6615,  lng: 80.0255, radiusKm: 15, factor: 1.05 },
  { name: 'Batticaloa',   lat: 7.7102,  lng: 81.6924, radiusKm: 12, factor: 1.05 },
  { name: 'Trincomalee',  lat: 8.5874,  lng: 81.2152, radiusKm: 12, factor: 1.05 },
  { name: 'Matara',       lat: 5.9549,  lng: 80.5550, radiusKm: 10, factor: 1.05 },
  { name: 'Anuradhapura', lat: 8.3114,  lng: 80.4037, radiusKm: 12, factor: 1.05 },
  // Tier C (rural) — all other coordinates fall through to factor 1.00
];

// Fallback city-name map for backward-compat area string lookups (tests / admin UI)
const DEFAULT_AREA_FACTORS = {
  Colombo:      1.15,
  Kandy:        1.15,
  Galle:        1.15,
  Negombo:      1.05,
  Kurunegala:   1.05,
  Ratnapura:    1.05,
  Jaffna:       1.05,
  Batticaloa:   1.05,
  Trincomalee:  1.05,
  Matara:       1.05,
  Anuradhapura: 1.05,
};

// ---------------------------------------------------------------------------
// Weather condition -> factor mapping (OpenWeatherMap "weather.main" values)
// Adapted for Sri Lankan tropical / monsoon weather — snow removed.
// ---------------------------------------------------------------------------
const WEATHER_FACTORS = {
  Thunderstorm: 1.50,
  Squall:       1.40,
  Rain:         1.30,
  Drizzle:      1.15,
  Fog:          1.15,
  Mist:         1.10,
  Haze:         1.10,
  Clouds:       1.05,
  Clear:        1.00,
};

// Demand/supply search radius when GPS coordinates are available (km)
const DEMAND_RADIUS_KM = 10;

// ---------------------------------------------------------------------------
// Haversine — great-circle distance in km between two GPS points
// ---------------------------------------------------------------------------
function haversineKm(lat1, lng1, lat2, lng2) {
  const R    = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---------------------------------------------------------------------------
// Geofence tier lookup — returns { factor, areaName } for a GPS coordinate.
// Falls back to factor 1.00 (Rural) if outside all hubs.
// ---------------------------------------------------------------------------
function getGeofenceTier(lat, lng, configFactors = {}) {
  for (const hub of GEOFENCE_HUBS) {
    if (haversineKm(lat, lng, hub.lat, hub.lng) <= hub.radiusKm) {
      // Allow admin to override per-hub factor via SystemConfig.autoAreaFactors
      const overrideFactor = configFactors[hub.name];
      return {
        areaName: hub.name,
        factor: (overrideFactor != null ? overrideFactor : hub.factor),
      };
    }
  }
  return { areaName: 'Rural', factor: 1.00 };
}

// ---------------------------------------------------------------------------
// Time-of-day factor (Sri Lanka time)
// ---------------------------------------------------------------------------
function getTimeFactor(hour) {
  if (hour >= 7  && hour <= 9)  return 1.25; // morning rush
  if (hour >= 17 && hour <= 20) return 1.30; // evening rush
  if (hour >= 22 || hour <= 2)  return 1.20; // late-night
  return 1.00;
}

// ---------------------------------------------------------------------------
// Demand/supply ratio -> factor
// ---------------------------------------------------------------------------
function getDemandSupplyFactor(activeRequests, availableDrivers) {
  const ratio = activeRequests / Math.max(availableDrivers, 1);
  if (ratio <= 1.0) return 1.00;
  if (ratio <= 1.5) return 1.15;
  if (ratio <= 2.0) return 1.35;
  if (ratio <= 2.5) return 1.55;
  return 1.75;
}

// ---------------------------------------------------------------------------
// Weather fetch — coordinate mode (preferred) or city-name fallback
// ---------------------------------------------------------------------------
async function fetchWeatherFactor({ lat, lng, area } = {}) {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey || apiKey.trim() === '' || apiKey === 'your-openweather-api-key') {
    return { factor: 1.0, condition: 'Unknown' };
  }
  try {
    let url;
    if (lat != null && lng != null) {
      // Hyper-local: query by exact GPS coordinates
      url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lng}&appid=${apiKey}`;
    } else {
      // Fallback: query by city name + Sri Lanka country code
      const city = encodeURIComponent((area || 'Colombo') + ',LK');
      url = `https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${apiKey}`;
    }
    const res = await fetch(url, { timeout: 5000 });
    if (!res.ok) return { factor: 1.0, condition: 'Unknown' };
    const data      = await res.json();
    const condition = data?.weather?.[0]?.main ?? 'Clear';
    return { factor: WEATHER_FACTORS[condition] ?? 1.0, condition };
  } catch {
    return { factor: 1.0, condition: 'Unknown' };
  }
}

// ---------------------------------------------------------------------------
// Demand/supply counts — coordinate mode uses a geospatial $geoWithin query;
// area string mode falls back to text-matching on driver.area field.
// ---------------------------------------------------------------------------
async function getDemandSupplyCounts(lat, lng, area) {
  if (lat != null && lng != null) {
    // Geospatial: count verified drivers within DEMAND_RADIUS_KM of the pickup point
    const radiusRadians = DEMAND_RADIUS_KM / 6371;
    const driverFilter = {
      isVerified: true,
      'location.type': 'Point',
      location: {
        $geoWithin: { $centerSphere: [[lng, lat], radiusRadians] },
      },
    };
    const driverIds = await Driver.distinct('_id', driverFilter);
    const [availableDrivers, activeRequests] = await Promise.all([
      Driver.countDocuments(driverFilter),
      RideRequest.countDocuments({ isActive: true, driver: { $in: driverIds } }),
    ]);
    return { availableDrivers, activeRequests };
  }

  // Fallback: text-match area field (backward compat)
  const areaFilter = area
    ? { $regex: new RegExp('^' + area + '$', 'i') }
    : { $exists: true };
  const driverFilter = { area: areaFilter, isVerified: true };
  const driverIds = await Driver.distinct('_id', driverFilter);
  const [availableDrivers, activeRequests] = await Promise.all([
    Driver.countDocuments(driverFilter),
    RideRequest.countDocuments({ isActive: true, driver: { $in: driverIds } }),
  ]);
  return { availableDrivers, activeRequests };
}

// ---------------------------------------------------------------------------
// Main export
//
// computeAutoRate({ lat, lng, area }, overrides)
//
//   lat, lng  (optional) — GPS coordinate mode:
//             weather by exact position, demand within DEMAND_RADIUS_KM radius,
//             area tier via virtual geofence — no manual city selection needed.
//
//   area      (optional) — fallback string mode:
//             backward compat for admin API preview, tests, and offline sync.
//
// Returns { effectiveRate, baseRate, multiplier, breakdown }
// ---------------------------------------------------------------------------
async function computeAutoRate({ lat, lng, area } = {}, overrides = {}) {
  const hasCoords = lat != null && lng != null;

  let config = await SystemConfig.findOne();
  if (!config) config = await SystemConfig.create({});

  const baseRate = overrides.baseRate ?? config.autoBaseRate ?? 100;
  const minM     = overrides.minMultiplier ?? config.autoMinMultiplier ?? 1.0;
  const maxM     = overrides.maxMultiplier ?? config.autoMaxMultiplier ?? 2.5;

  // ── Area tier factor ───────────────────────────────────────────────────────
  let areaFactor;
  let resolvedAreaName;

  if (hasCoords) {
    // Virtual geofence — driver location determines tier automatically
    const configFactors = config.autoAreaFactors?.toObject?.() ?? {};
    const tier   = getGeofenceTier(lat, lng, configFactors);
    areaFactor       = tier.factor;
    resolvedAreaName = tier.areaName;
  } else {
    // String-based fallback (tests / admin preview / offline sync)
    const factorsMap = {
      ...DEFAULT_AREA_FACTORS,
      ...(config.autoAreaFactors?.toObject?.() ?? {}),
    };
    const areaKey = Object.keys(factorsMap).find(
      (k) => k.toLowerCase() === (area || '').toLowerCase()
    );
    areaFactor       = areaKey ? (factorsMap[areaKey] ?? 1.0) : 1.0;
    resolvedAreaName = areaKey || area || 'Unknown';
  }

  // ── Demand / supply ──────────────────────────────────────────────────────
  const { availableDrivers, activeRequests } = await getDemandSupplyCounts(
    hasCoords ? lat  : null,
    hasCoords ? lng  : null,
    area
  );
  const demandSupplyFactor = getDemandSupplyFactor(activeRequests, availableDrivers);

  // ── Time of day ─────────────────────────────────────────────────────────
  const sriLankaHour = Number(
    new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Colombo',
      hour: 'numeric',
      hourCycle: 'h23',
    }).format(new Date())
  );
  const timeFactor = getTimeFactor(sriLankaHour);

  // ── Weather ─────────────────────────────────────────────────────────────
  const { factor: weatherFactor, condition: weatherCondition } =
    await fetchWeatherFactor({
      lat:  hasCoords ? lat  : null,
      lng:  hasCoords ? lng  : null,
      area,
    });

  // ── Weighted combination (weights: 0.50 + 0.25 + 0.15 + 0.10 = 1.00) ──
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
      resolvedArea: resolvedAreaName,
      coordMode: hasCoords,
    },
  };
}

module.exports = { computeAutoRate };

