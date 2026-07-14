export function buildAnalyticsData(drivers = [], trips = []) {
  const completedTrips = trips.filter((trip) => trip.status === 'completed');
  const revenue = completedTrips.reduce((sum, trip) => sum + Number(trip.totalFare || 0), 0);

  const tripCountsByHour = completedTrips.reduce((acc, trip) => {
    const hour = new Date(trip.startTime).getUTCHours();
    acc[hour] = (acc[hour] || 0) + 1;
    return acc;
  }, {});

  const peakHourEntries = Object.entries(tripCountsByHour)
    .map(([hour, count]) => ({ hour: Number(hour), label: `${String(hour).padStart(2, '0')}:00`, count }))
    .sort((a, b) => b.count - a.count || a.hour - b.hour);

  const peakHour = peakHourEntries[0];
  const peakHourLabel = peakHour ? peakHour.label : '—';
  const peakHours = peakHourEntries.slice(0, 10);

  const driverTripCounts = completedTrips.reduce((acc, trip) => {
    const name = trip.driver?.name || 'Unknown';
    acc[name] = (acc[name] || 0) + 1;
    return acc;
  }, {});

  const topDrivers = Object.entries(driverTripCounts)
    .sort((a, b) => b[1] - a[1])
    .map(([name, trips]) => ({ name, trips }));

  const tripTrend = completedTrips.reduce((acc, trip) => {
    const day = new Date(trip.startTime).toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
    acc[day] = (acc[day] || 0) + 1;
    return acc;
  }, {});

  return {
    summary: {
      totalDrivers: drivers.length,
      verifiedDrivers: drivers.filter((driver) => driver.isVerified).length,
      totalTrips: trips.length,
      completedTrips: completedTrips.length,
      revenue,
    },
    peakHour: peakHourLabel,
    peakHours,
    topDrivers,
    tripTrend,
  };
}
