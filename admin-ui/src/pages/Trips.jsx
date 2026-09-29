import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Trips() {
  const [trips, setTrips] = useState([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
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

  const visibleTrips = trips.filter((trip) => {
    const term = search.toLowerCase();
    const matchesSearch = [trip.customerName, trip.startLocation, trip.endLocation, trip.driver?.name]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()
      .includes(term);
    const matchesStatus = statusFilter === 'all' || trip.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div style={styles.page}>
      <style>{`
        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .trip-nav button:hover {
          opacity: 0.92;
          transform: translateY(-1px);
        }
        .trip-search:focus,
        .trip-select:focus {
          border-color: #6c7cff;
          box-shadow: 0 0 0 4px rgba(108, 124, 255, 0.18);
        }
        .trip-table tbody tr:hover {
          background: #f8fbff;
        }
        @keyframes shimmer {
          0% { background-position: -200px 0; }
          100% { background-position: calc(200px + 100%) 0; }
        }
      `}</style>
      <nav style={styles.nav} className="trip-nav">
        <span style={styles.navTitle}>Taxi Meter Admin</span>
        <div>
          <button style={styles.navBtn} onClick={() => navigate('/dashboard')}>Dashboard</button>
          <button style={styles.navBtn} onClick={() => navigate('/drivers')}>Drivers</button>
          <button style={{ ...styles.navBtn, ...styles.navBtnActive }} aria-current="page" onClick={() => navigate('/trips')}>Trips</button>
          <button style={styles.navBtn} onClick={() => navigate('/pricing')}>Pricing</button>
          <button style={{ ...styles.navBtn, color: '#e74c3c' }} onClick={handleLogout}>Logout</button>
        </div>
      </nav>

      <div style={styles.content}>
        <div style={styles.header}>
          <h2 style={styles.pageTitle}>All Trips</h2>
          <div style={styles.headerActions}>
            <input
              style={styles.searchInput}
              className="trip-search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search trips"
            />
            <select style={styles.select} className="trip-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="all">All statuses</option>
              <option value="completed">Completed</option>
              <option value="ongoing">Ongoing</option>
              <option value="cancelled">Cancelled</option>
              <option value="pending">Pending</option>
            </select>
          </div>
        </div>

        {loading && (
          <div style={styles.skeletonWrapper}>
            {Array.from({ length: 6 }).map((_, index) => (
              <div key={index} style={styles.skeletonRow}>
                {Array.from({ length: 10 }).map((__, cellIndex) => (
                  <div key={cellIndex} style={styles.skeletonCell} />
                ))}
              </div>
            ))}
          </div>
        )}
        {error && <p style={styles.error}>{error}</p>}
        {!loading && !error && visibleTrips.length === 0 && (
          <p style={styles.info}>No trips recorded yet.</p>
        )}

        {!loading && visibleTrips.length > 0 && (
          <div style={styles.tableWrap}>
            <table style={styles.table} className="trip-table">
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
                {visibleTrips.map((t) => (
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
  navBtnActive: { background: 'rgba(255,255,255,0.06)', borderRadius: '8px', padding: '0.45rem 0.7rem', fontWeight: 600, boxShadow: 'inset 0 -2px 0 rgba(173,185,230,0.55)' },
  content: { padding: '2rem' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1rem', marginBottom: '1.5rem', flexWrap: 'wrap' },
  headerActions: { display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' },
  pageTitle: { fontSize: '1.4rem', color: '#1a1a2e', marginBottom: 0 },
  searchInput: { padding: '0.45rem 0.8rem', border: '1px solid #ccc', borderRadius: '4px', minWidth: '220px' },
  select: { padding: '0.45rem 0.8rem', border: '1px solid #ccc', borderRadius: '4px', background: '#fff' },
  tableWrap: { overflowX: 'auto', background: '#fff', borderRadius: '8px', boxShadow: '0 1px 6px rgba(0,0,0,0.08)' },
  skeletonWrapper: { background: '#fff', borderRadius: '16px', border: '1px solid rgba(206, 216, 240, 0.9)', padding: '1rem', boxShadow: '0 14px 36px rgba(20, 35, 90, 0.06)', display: 'grid', gap: '0.85rem', animation: 'fadeUp 0.35s ease-out' },
  skeletonRow: { display: 'grid', gridTemplateColumns: 'repeat(10, minmax(0, 1fr))', gap: '0.75rem', alignItems: 'center' },
  skeletonCell: { height: '1rem', borderRadius: '999px', background: 'linear-gradient(90deg, #eef2ff 0%, #f6f8ff 50%, #eef2ff 100%)', animation: 'shimmer 1.6s ease-in-out infinite' },
  table: { width: '100%', borderCollapse: 'collapse' },
  thead: { background: '#f7f8fa' },
  th: { padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.85rem', color: '#555', borderBottom: '1px solid #eee' },
  tr: { borderBottom: '1px solid #f0f0f0' },
  td: { padding: '0.75rem 1rem', fontSize: '0.9rem', color: '#333' },
  badge: { padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  info: { color: '#888', textAlign: 'center', marginTop: '2rem' },
  error: { color: '#c0392b', textAlign: 'center', marginTop: '2rem' },
};
