import { buildAnalyticsData } from './adminAnalytics';

describe('buildAnalyticsData', () => {
  it('summarizes drivers and trips into dashboard metrics', () => {
    const drivers = [
      { _id: '1', isVerified: true, name: 'Alice' },
      { _id: '2', isVerified: false, name: 'Bob' },
    ];

    const trips = [
      {
        _id: 't1',
        status: 'completed',
        totalFare: 100,
        startTime: '2025-01-15T08:30:00Z',
        driver: { name: 'Alice' },
      },
      {
        _id: 't2',
        status: 'completed',
        totalFare: 150,
        startTime: '2025-01-16T20:15:00Z',
        driver: { name: 'Alice' },
      },
      {
        _id: 't3',
        status: 'cancelled',
        totalFare: 0,
        startTime: '2025-01-17T10:00:00Z',
        driver: { name: 'Bob' },
      },
    ];

    const result = buildAnalyticsData(drivers, trips);

    expect(result.summary.totalDrivers).toBe(2);
    expect(result.summary.verifiedDrivers).toBe(1);
    expect(result.summary.totalTrips).toBe(3);
    expect(result.summary.completedTrips).toBe(2);
    expect(result.summary.revenue).toBe(250);
    expect(result.peakHour).toBe('20:00');
    expect(result.peakHours[0].label).toBe('20:00');
    expect(result.peakHours[0].count).toBe(1);
    expect(result.topDrivers[0].name).toBe('Alice');
    expect(result.topDrivers[0].trips).toBe(2);
  });
});
