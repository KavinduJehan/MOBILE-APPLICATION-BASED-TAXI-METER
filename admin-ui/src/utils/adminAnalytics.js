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

export function getWeeklyTripsByDay(trips = [], weekStartDate = new Date()) {
  // Normalize to Monday start of week
  const startDate = new Date(weekStartDate);
  const dayOfWeek = startDate.getDay();
  const diff = startDate.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1);
  startDate.setDate(diff);
  startDate.setHours(0, 0, 0, 0);

  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + 7);

  const completedTrips = trips.filter((trip) => trip.status === 'completed');
  
  const tripsInWeek = completedTrips.filter((trip) => {
    const tripDate = new Date(trip.startTime);
    return tripDate >= startDate && tripDate < endDate;
  });

  const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const tripsByDay = {
    Monday: 0,
    Tuesday: 0,
    Wednesday: 0,
    Thursday: 0,
    Friday: 0,
    Saturday: 0,
    Sunday: 0,
  };

  tripsInWeek.forEach((trip) => {
    const tripDate = new Date(trip.startTime);
    const dayIndex = (tripDate.getDay() + 6) % 7; // Convert Sun=0 to Mon=0
    const dayName = daysOfWeek[dayIndex];
    tripsByDay[dayName] = (tripsByDay[dayName] || 0) + 1;
  });

  return {
    startDate,
    endDate,
    data: daysOfWeek.map((day) => ({
      day,
      count: tripsByDay[day],
    })),
  };
}
