const { computeAutoRate } = require('./pricingEngine');

// The pricing mode that applies to a driver: their own setting first, then the
// system-wide mode, then the regulated default.
const resolvePricingMode = (driver, config) =>
  driver?.pricingMode || config?.rateMode || 'ADMIN';

// The per-km rate a customer is actually charged for this driver right now.
// This is the single source of truth: the same value is shown to the customer
// when browsing drivers and stored on the ride request as the quoted rate, so
// the customer, the driver and the fare can never disagree.
//
//   DRIVER – the driver's own rate
//   ADMIN  – the regulator's fixed rate
//   AUTO   – the live surge rate at the pickup point
const resolveEffectiveRate = async (driver, config, { lat, lng } = {}) => {
  const mode = resolvePricingMode(driver, config);

  if (mode === 'AUTO') {
    const hasCoords = Number.isFinite(lat) && Number.isFinite(lng);
    const price = await computeAutoRate(
      hasCoords ? { lat, lng } : { area: driver?.area },
    );
    return { mode, rate: price.effectiveRate, breakdown: price.breakdown };
  }
  if (mode === 'ADMIN') {
    return {
      mode,
      rate: config?.autoBaseRate || driver?.ratePerKm || 100,
      breakdown: null,
    };
  }
  return { mode, rate: driver?.ratePerKm, breakdown: null };
};

module.exports = { resolvePricingMode, resolveEffectiveRate };
