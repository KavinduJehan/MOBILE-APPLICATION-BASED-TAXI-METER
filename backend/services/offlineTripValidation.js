const { verifyIdentity } = require('./offlineIdentity');

const validateOfflineSnapshot = (item, driver, now = Date.now()) => {
  if (item.version !== 1 || !/^offline-[a-f0-9]{32}$/.test(item.localId || '')) {
    throw new Error('A version 1 offline trip ID is required');
  }
  if (item.driverId !== String(driver._id) || item.driverToken !== driver.qrToken) {
    throw new Error('Offline trip is not addressed to this driver');
  }
  if (item.status !== 'completed') throw new Error('Only completed offline trips can be synced');
  const distanceKm = item.distanceKm;
  const ratePerKm = item.ratePerKm;
  if (typeof distanceKm !== 'number' || !Number.isFinite(distanceKm) || distanceKm < 0 ||
      typeof ratePerKm !== 'number' || !Number.isFinite(ratePerKm) || ratePerKm <= 0) {
    throw new Error('Valid offline distance and agreed rate are required');
  }
  const totalFare = Number((distanceKm * ratePerKm).toFixed(2));
  if (!Number.isFinite(item.totalFare) || Math.abs(item.totalFare - totalFare) > 0.011) {
    throw new Error('Offline fare must match the recorded distance and agreed rate');
  }
  const startTime = new Date(item.startTime);
  const endTime = new Date(item.endTime);
  const offerTime = new Date(item.offerTimestamp);
  if (!Number.isFinite(startTime.getTime()) || !Number.isFinite(endTime.getTime()) ||
      !Number.isFinite(offerTime.getTime()) || endTime < startTime ||
      endTime.getTime() > now + 5 * 60 * 1000 ||
      Math.abs(startTime - offerTime) > 30 * 60 * 1000) {
    throw new Error('Valid offline offer, start and end times are required');
  }
  const customer = item.customerIdentity && verifyIdentity(item.customerIdentity, item.customerId, startTime)
    ? item.customerId : null;
  return { distanceKm, ratePerKm, totalFare, startTime, endTime, customer,
    receiptNumber: `REC-${item.localId.toUpperCase()}` };
};

module.exports = { validateOfflineSnapshot };
