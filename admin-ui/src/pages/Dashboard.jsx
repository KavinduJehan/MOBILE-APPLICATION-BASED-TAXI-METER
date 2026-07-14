import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import { buildAnalyticsData } from '../utils/adminAnalytics';

export default function Dashboard() {
  const [drivers, setDrivers] = useState([]);
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAllDrivers, setShowAllDrivers] = useState(false);
  const [hoveredHour, setHoveredHour] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    const loadData = async () => {
      try {
        const [driversRes, tripsRes] = await Promise.all([
          api.get('/admin/drivers'),
          api.get('/admin/trips'),
        ]);
        setDrivers(driversRes.data || []);
        setTrips(tripsRes.data || []);
      } catch (err) {
        setError('Failed to load dashboard data.');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  const analytics = useMemo(() => buildAnalyticsData(drivers || [], trips || []), [drivers, trips]);
  const summary = analytics?.summary || {};
  const tripTrend = analytics?.tripTrend || {};
  const peakHours = Array.isArray(analytics?.peakHours) ? analytics.peakHours : [];
  const topDrivers = Array.isArray(analytics?.topDrivers) ? analytics.topDrivers : [];
  const visibleDrivers = showAllDrivers ? topDrivers : topDrivers.slice(0, 3);

  const trendEntries = Object.entries(tripTrend).slice(-7);
  const trendMax = Math.max(...trendEntries.map(([, count]) => Number(count || 0)), 1);
  const chartWidth = 360;
  const chartHeight = 180;
  const padding = 24;
  const trendPoints = trendEntries.map(([label, count], index) => {
    const x = padding + (index * (chartWidth - padding * 2)) / Math.max(trendEntries.length - 1, 1);
    const y = chartHeight - padding - (Number(count || 0) / trendMax) * (chartHeight - padding * 2);
    return { label, x, y, count };
  });

  const trendPath = trendPoints.map((point) => `${point.x},${point.y}`).join(' ');
  const areaPath = `M ${padding},${chartHeight - padding} L ${trendPoints.map((point) => `${point.x},${point.y}`).join(' L ')} L ${chartWidth - padding},${chartHeight - padding} Z`;
  const linePath = trendPoints.map((point) => `${point.x},${point.y}`).join(' ');

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login');
  };

  return (
    <div style={styles.page}>
      <style>{`
        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(12px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes pulseGlow {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.03); }
        }
      `}</style>

      <nav style={styles.nav}>
        <span style={styles.navTitle}>Taxi Meter Admin</span>
        <div>
          <button style={styles.navBtn} onClick={() => navigate('/dashboard')}>Dashboard</button>
          <button style={styles.navBtn} onClick={() => navigate('/drivers')}>Drivers</button>
          <button style={styles.navBtn} onClick={() => navigate('/trips')}>Trips</button>
          <button style={{ ...styles.navBtn, color: '#ff8a8a' }} onClick={handleLogout}>Logout</button>
        </div>
      </nav>

      <div style={styles.content}>
        <div style={styles.heroCard}>
          <div>
            <p style={styles.eyebrow}>Operations overview</p>
            <h2 style={styles.pageTitle}>Admin Dashboard</h2>
          </div>
          <div style={styles.heroBadge}>Live insights</div>
        </div>

        {loading && <p style={styles.info}>Loading analytics...</p>}
        {error && <p style={styles.error}>{error}</p>}

        {!loading && !error && (
          <>
            <div style={styles.cardsGrid}>
              <div style={styles.card}>
                <div style={styles.cardLabel}>Total Drivers</div>
                <div style={styles.cardValue}>{summary.totalDrivers || 0}</div>
              </div>
              <div style={styles.card}>
                <div style={styles.cardLabel}>Verified Drivers</div>
                <div style={styles.cardValue}>{summary.verifiedDrivers || 0}</div>
              </div>
              <div style={styles.card}>
                <div style={styles.cardLabel}>Completed Trips</div>
                <div style={styles.cardValue}>{summary.completedTrips || 0}</div>
              </div>
              <div style={styles.card}>
                <div style={styles.cardLabel}>Revenue</div>
                <div style={styles.cardValue}>LKR {summary.revenue || 0}</div>
              </div>
            </div>

            <div style={styles.panelGrid}>
              <div style={styles.panel}>
                <div style={styles.panelHeader}>
                  <h3 style={styles.panelTitle}>Trip trend</h3>
                  <span style={styles.panelPill}>Weekly view</span>
                </div>
                {trendEntries.length > 0 ? (
                  <>
                    <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} style={styles.chartSvg}>
                      <defs>
                        <linearGradient id="trendFill" x1="0%" y1="0%" x2="0%" y2="100%">
                          <stop offset="0%" stopColor="#6c7cff" stopOpacity="0.35" />
                          <stop offset="100%" stopColor="#6c7cff" stopOpacity="0.04" />
                        </linearGradient>
                      </defs>
                      <path d={areaPath} fill="url(#trendFill)" />
                      <polyline points={linePath} fill="none" stroke="#5b6cff" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
                      {trendPoints.map((point) => (
                        <circle key={point.label} cx={point.x} cy={point.y} r="5" fill="#ffffff" stroke="#5b6cff" strokeWidth="3" />
                      ))}
                    </svg>
                    <div style={styles.chartLegend}>
                      {trendPoints.map((point) => (
                        <div key={point.label} style={styles.chartLegendItem}>
                          <span style={styles.legendDot} />
                          <span>{point.label}</span>
                        </div>
                      ))}
                    </div>
                  </>
                ) : (
                  <div style={styles.info}>No trend data available yet.</div>
                )}
              </div>

              <div style={styles.panel}>
                <div style={styles.panelHeader}>
                  <h3 style={styles.panelTitle}>Peak hours</h3>
                  <span style={styles.panelPill}>Busy windows</span>
                </div>
                <div style={styles.cardLabel}>Most demanded completion window</div>
                {peakHours.length > 0 ? (
                  <div style={styles.barChart}>
                    {peakHours.map((hour, index) => {
                      const maxValue = Math.max(...peakHours.map((entry) => entry.count), 1);
                      const height = Math.max(18, (hour.count / maxValue) * 100);
                      return (
                        <div
                          key={`${hour.label}-${index}`}
                          style={styles.barColumn}
                          onMouseEnter={() => setHoveredHour(hour.label)}
                          onMouseLeave={() => setHoveredHour(null)}
                        >
                          <div style={styles.barTooltipWrapper}>
                            {hoveredHour === hour.label && (
                              <div style={styles.barTooltip}>{hour.count} trips</div>
                            )}
                            <div style={styles.barTrackShell}>
                              <div style={{ ...styles.barFill, height: `${height}%` }} />
                            </div>
                          </div>
                          <span style={styles.barLabel}>{hour.label}</span>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div style={styles.info}>No peak-hour data yet.</div>
                )}
              </div>
            </div>

            <div style={styles.panelGrid}>
              <div style={styles.panel}>
                <div style={styles.panelHeader}>
                  <h3 style={styles.panelTitle}>Top drivers</h3>
                  <span style={styles.panelPill}>Most active</span>
                </div>
                <div style={styles.list}>
                  {topDrivers.length > 0 ? (
                    <>
                      {visibleDrivers.map((driver, index) => (
                        <div key={driver.name} style={styles.listRow}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.7rem' }}>
                            <span style={{ ...styles.rankBadge, background: index === 0 ? '#6c7cff' : '#e7ebff' }}>{index + 1}</span>
                            <span>{driver.name}</span>
                          </div>
                          <strong>{driver.trips} trips</strong>
                        </div>
                      ))}
                      {topDrivers.length > 3 && (
                        <button style={styles.dropdownBtn} onClick={() => setShowAllDrivers((prev) => !prev)}>
                          {showAllDrivers ? '▴ Show fewer drivers' : '▾ Show all'}
                        </button>
                      )}
                    </>
                  ) : (
                    <div style={styles.info}>No driver trip data available.</div>
                  )}
                </div>
              </div>

              <div style={styles.panel}>
                <div style={styles.panelHeader}>
                  <h3 style={styles.panelTitle}>Quick actions</h3>
                  <span style={styles.panelPill}>Navigate</span>
                </div>
                <div style={styles.actions}>
                  <button style={styles.actionBtn} onClick={() => navigate('/drivers')}>Manage Drivers</button>
                  <button style={styles.actionBtn} onClick={() => navigate('/trips')}>Review Trips</button>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

const styles = {
  page: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #f5f7ff 0%, #eef2ff 100%)',
    fontFamily: 'Inter, Segoe UI, sans-serif',
  },
  nav: {
    background: 'linear-gradient(90deg, #1a1a2e 0%, #27314d 100%)',
    color: '#fff',
    padding: '0.9rem 2rem',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    boxShadow: '0 8px 24px rgba(26, 26, 46, 0.18)',
  },
  navTitle: { fontWeight: 'bold', fontSize: '1.1rem', letterSpacing: '0.02em' },
  navBtn: {
    background: 'none',
    border: 'none',
    color: '#fff',
    cursor: 'pointer',
    marginLeft: '1rem',
    fontSize: '0.95rem',
    transition: 'opacity 0.2s ease',
  },
  content: { padding: '2rem', maxWidth: '1200px', margin: '0 auto' },
  heroCard: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '1.2rem 1.4rem',
    borderRadius: '18px',
    background: 'rgba(255,255,255,0.82)',
    boxShadow: '0 14px 30px rgba(34, 42, 72, 0.08)',
    marginBottom: '1.2rem',
    backdropFilter: 'blur(12px)',
    animation: 'fadeUp 0.45s ease-out',
  },
  eyebrow: { margin: 0, color: '#6c7cff', fontSize: '0.8rem', letterSpacing: '0.18em', textTransform: 'uppercase' },
  pageTitle: { fontSize: '1.45rem', color: '#1a1a2e', margin: '0.2rem 0' },
  subtitle: { color: '#68708a', margin: '0.2rem 0 0', maxWidth: '620px' },
  heroBadge: {
    background: 'linear-gradient(135deg, #6c7cff, #8b95ff)',
    color: '#fff',
    borderRadius: '999px',
    padding: '0.55rem 0.9rem',
    fontSize: '0.9rem',
    fontWeight: 700,
    animation: 'pulseGlow 2s ease-in-out infinite',
  },
  cardsGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '1rem' },
  card: {
    background: '#fff',
    borderRadius: '16px',
    padding: '1rem 1.1rem',
    boxShadow: '0 10px 24px rgba(23, 34, 71, 0.08)',
    border: '1px solid rgba(108, 124, 255, 0.12)',
    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
    animation: 'fadeUp 0.5s ease-out',
  },
  cardLabel: { color: '#5b6078', fontSize: '0.9rem', marginBottom: '0.3rem' },
  cardValue: { fontSize: '1.35rem', fontWeight: 700, color: '#1a1a2e' },
  cardHint: { color: '#8990a6', fontSize: '0.8rem', marginTop: '0.25rem' },
  panelGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1rem', marginTop: '1rem' },
  panel: {
    background: '#fff',
    borderRadius: '16px',
    padding: '1rem 1.1rem',
    boxShadow: '0 10px 24px rgba(23, 34, 71, 0.08)',
    border: '1px solid rgba(108, 124, 255, 0.12)',
    animation: 'fadeUp 0.55s ease-out',
  },
  panelHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.65rem' },
  panelTitle: { margin: 0, fontSize: '1rem', color: '#1a1a2e' },
  panelPill: { fontSize: '0.76rem', padding: '0.26rem 0.6rem', borderRadius: '999px', background: '#eef2ff', color: '#5b6cff' },
  list: { display: 'flex', flexDirection: 'column', gap: '0.55rem' },
  listRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '0.55rem', borderBottom: '1px solid #f0f0f0' },
  rankBadge: { width: '24px', height: '24px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: '0.8rem', fontWeight: 700 },
  highlight: { fontSize: '2rem', fontWeight: 700, color: '#27ae60' },
  chartSvg: { width: '100%', height: '180px', marginTop: '0.3rem' },
  chartLegend: { display: 'flex', flexWrap: 'wrap', gap: '0.5rem 0.8rem', marginTop: '0.2rem', color: '#68708a', fontSize: '0.8rem' },
  chartLegendItem: { display: 'flex', alignItems: 'center', gap: '0.35rem' },
  legendDot: { width: '8px', height: '8px', borderRadius: '50%', background: '#5b6cff' },
  barChart: { display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: '0.45rem', height: '210px', marginTop: '1rem' },
  barColumn: { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.25rem', cursor: 'pointer' },
  barTooltipWrapper: { position: 'relative', display: 'flex', alignItems: 'flex-end', justifyContent: 'center', width: '100%' },
  barTooltip: { position: 'absolute', top: '-38px', background: '#1a1a2e', color: '#fff', padding: '0.35rem 0.6rem', borderRadius: '999px', fontSize: '0.76rem', whiteSpace: 'nowrap', zIndex: 2, boxShadow: '0 8px 20px rgba(0,0,0,0.15)' },
  barTrackShell: { width: '100%', maxWidth: '36px', height: '150px', borderRadius: '999px', background: '#e8edff', display: 'flex', alignItems: 'flex-end', padding: '4px', boxSizing: 'border-box', border: '1px solid #d9e2ff' },
  barFill: { width: '100%', minHeight: '20px', borderRadius: '999px', background: '#3c57ff', boxShadow: '0 8px 18px rgba(60, 87, 255, 0.24)', transition: 'height 0.3s ease' },
  barValue: { fontSize: '0.8rem', color: '#1a1a2e', fontWeight: 700 },
  barLabel: { fontSize: '0.78rem', color: '#68708a' },
  toggleBtn: { marginTop: '0.4rem', alignSelf: 'flex-start', background: '#eef2ff', border: '1px solid #dbe3ff', color: '#5b6cff', cursor: 'pointer', fontWeight: 700, padding: '0.45rem 0.75rem', borderRadius: '999px', textAlign: 'left' },
  dropdownBtn: { marginTop: '0.4rem', alignSelf: 'flex-start', background: '#fff', border: '1px solid #ced7ff', color: '#3c57ff', cursor: 'pointer', fontWeight: 700, padding: '0.5rem 0.85rem', borderRadius: '12px', textAlign: 'left', boxShadow: '0 6px 14px rgba(60, 87, 255, 0.12)' },
  actions: { display: 'flex', gap: '0.75rem', flexWrap: 'wrap', marginTop: '0.4rem' },
  actionBtn: { background: 'linear-gradient(135deg, #1a1a2e, #27314d)', color: '#fff', border: 'none', padding: '0.7rem 0.95rem', borderRadius: '10px', cursor: 'pointer', transition: 'transform 0.2s ease, box-shadow 0.2s ease' },
  info: { color: '#888', marginTop: '1rem' },
  error: { color: '#c0392b', marginTop: '1rem' },
};
