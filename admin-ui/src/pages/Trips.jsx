import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Trips() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchTrips = async () => {
      try {
        const res = await api.get('/admin/trips');
        setTrips(res.data);
      } catch (err) {
        setError('Failed to load trips.');
      } finally {
        setLoading(false);
      }
    };
    fetchTrips();
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login');
  };

  const formatDate = (iso) =>
    iso ? new Date(iso).toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' }) : '—';

  const statusColor = (s) => {
    const map = {
      ongoing: { background: '#cce5ff', color: '#004085' },
      completed: { background: '#d4edda', color: '#155724' },
      cancelled: { background: '#f8d7da', color: '#721c24' },
      pending: { background: '#fff3cd', color: '#856404' },
    };
    return map[s] || {};
  };

  return (
    <div style={styles.page}>
      <nav style={styles.nav}>
        <span style={styles.navTitle}>Taxi Meter Admin</span>
        <div>
          <button style={styles.navBtn} onClick={() => navigate('/drivers')}>Drivers</button>
          <button style={styles.navBtn} onClick={() => navigate('/trips')}>Trips</button>
          <button style={{ ...styles.navBtn, color: '#e74c3c' }} onClick={handleLogout}>Logout</button>
        </div>
      </nav>

      <div style={styles.content}>
        <h2 style={styles.pageTitle}>All Trips</h2>

        {loading && <p style={styles.info}>Loading...</p>}
        {error && <p style={styles.error}>{error}</p>}
        {!loading && !error && trips.length === 0 && (
          <p style={styles.info}>No trips recorded yet.</p>
        )}

        {!loading && trips.length > 0 && (
          <div style={styles.tableWrap}>
            <table style={styles.table}>
              <thead>
                <tr style={styles.thead}>
                  <th style={styles.th}>Driver</th>
                  <th style={styles.th}>Customer</th>
                  <th style={styles.th}>From</th>
                  <th style={styles.th}>To</th>
                  <th style={styles.th}>Distance</th>
                  <th style={styles.th}>Rate/km</th>
                  <th style={styles.th}>Total Fare</th>
                  <th style={styles.th}>Start</th>
                  <th style={styles.th}>End</th>
                  <th style={styles.th}>Status</th>
                </tr>
              </thead>
              <tbody>
                {trips.map((t) => (
                  <tr key={t._id} style={styles.tr}>
                    <td style={styles.td}>
                      <div style={{ fontWeight: 500 }}>{t.driver?.name || '—'}</div>
                      <div style={{ fontSize: '0.78rem', color: '#888' }}>{t.driver?.vehicleNumber}</div>
                    </td>
                    <td style={styles.td}>{t.customerName}</td>
                    <td style={styles.td}>{t.startLocation}</td>
                    <td style={styles.td}>{t.endLocation}</td>
                    <td style={styles.td}>{t.distanceKm} km</td>
                    <td style={styles.td}>LKR {t.ratePerKm}</td>
                    <td style={{ ...styles.td, fontWeight: 600 }}>LKR {t.totalFare}</td>
                    <td style={styles.td}>{formatDate(t.startTime)}</td>
                    <td style={styles.td}>{formatDate(t.endTime)}</td>
                    <td style={styles.td}>
                      <span style={{ ...styles.badge, ...statusColor(t.status) }}>
                        {t.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

const styles = {
  page: { minHeight: '100vh', background: '#f0f2f5' },
  nav: {
    background: '#1a1a2e', color: '#fff', padding: '0.8rem 2rem',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  },
  navTitle: { fontWeight: 'bold', fontSize: '1.1rem' },
  navBtn: {
    background: 'none', border: 'none', color: '#fff',
    cursor: 'pointer', marginLeft: '1rem', fontSize: '0.95rem',
  },
  content: { padding: '2rem' },
  pageTitle: { fontSize: '1.4rem', color: '#1a1a2e', marginBottom: '1.5rem' },
  tableWrap: { overflowX: 'auto', background: '#fff', borderRadius: '8px', boxShadow: '0 1px 6px rgba(0,0,0,0.08)' },
  table: { width: '100%', borderCollapse: 'collapse' },
  thead: { background: '#f7f8fa' },
  th: { padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.85rem', color: '#555', borderBottom: '1px solid #eee' },
  tr: { borderBottom: '1px solid #f0f0f0' },
  td: { padding: '0.75rem 1rem', fontSize: '0.9rem', color: '#333' },
  badge: { padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  info: { color: '#888', textAlign: 'center', marginTop: '2rem' },
  error: { color: '#c0392b', textAlign: 'center', marginTop: '2rem' },
};
