import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Drivers() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const fetchDrivers = async (currentFilter) => {
    setLoading(true);
    setError('');
    try {
      const param = currentFilter === 'all' ? '' : `?verified=${currentFilter === 'verified'}`;
      const res = await api.get(`/admin/drivers${param}`);
      setDrivers(res.data);
    } catch (err) {
      setError('Failed to load drivers.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDrivers(filter);
  }, [filter]);

  const handleVerify = async (id, isVerified) => {
    try {
      await api.patch(`/admin/drivers/${id}/verify`, { isVerified });
      fetchDrivers(filter);
    } catch (err) {
      alert('Failed to update driver: ' + (err.response?.data?.message || err.message));
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login');
  };

  const visibleDrivers = drivers.filter((driver) => {
    const term = search.toLowerCase();
    return [driver.name, driver.email, driver.phone, driver.area, driver.vehicleNumber]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()
      .includes(term);
  });

  return (
    <div style={styles.page}>
      <style>{`
        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .driver-nav button:hover {
          opacity: 0.92;
          transform: translateY(-1px);
        }
        .driver-search:focus {
          border-color: #6c7cff;
          box-shadow: 0 0 0 4px rgba(108, 124, 255, 0.18);
        }
        .driver-filter:hover {
          transform: translateY(-1px);
          background: #f4f7ff;
        }
        .driver-table tbody tr:hover {
          background: #f8fbff;
        }
        @keyframes shimmer {
          0% { background-position: -200px 0; }
          100% { background-position: calc(200px + 100%) 0; }
        }
      `}</style>
      <nav style={styles.nav} className="driver-nav">
        <span style={styles.navTitle}>Taxi Meter Admin</span>
        <div>
          <button style={styles.navBtn} onClick={() => navigate('/dashboard')}>Dashboard</button>
          <button style={styles.navBtn} onClick={() => navigate('/drivers')}>Drivers</button>
          <button style={styles.navBtn} onClick={() => navigate('/trips')}>Trips</button>
          <button style={{ ...styles.navBtn, color: '#e74c3c' }} onClick={handleLogout}>Logout</button>
        </div>
      </nav>

      <div style={styles.content}>
        <div style={styles.header}>
          <h2 style={styles.pageTitle}>Driver Management</h2>
          <div style={styles.headerActions}>
            <input
              style={styles.searchInput}
              className="driver-search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search drivers"
            />
            {['all', 'pending', 'verified'].map((f) => (
              <button
                key={f}
                className="driver-filter"
                style={{ ...styles.filterBtn, ...(filter === f ? styles.filterActive : {}) }}
                onClick={() => setFilter(f)}
              >
                {f.charAt(0).toUpperCase() + f.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {loading && (
          <div style={styles.skeletonWrapper}>
            {Array.from({ length: 5 }).map((_, index) => (
              <div key={index} style={styles.skeletonRow}>
                {Array.from({ length: 9 }).map((__, cellIndex) => (
                  <div key={cellIndex} style={styles.skeletonCell} />
                ))}
              </div>
            ))}
          </div>
        )}
        {error && <p style={styles.error}>{error}</p>}
        {!loading && !error && visibleDrivers.length === 0 && (
          <p style={styles.info}>No drivers found.</p>
        )}

        {!loading && visibleDrivers.length > 0 && (
          <div style={styles.tableWrap}>
            <table style={styles.table}>
              <thead>
                <tr style={styles.thead}>
                  <th style={styles.th}>Name</th>
                  <th style={styles.th}>Email</th>
                  <th style={styles.th}>Phone</th>
                  <th style={styles.th}>License</th>
                  <th style={styles.th}>Vehicle</th>
                  <th style={styles.th}>Area</th>
                  <th style={styles.th}>Rate/km</th>
                  <th style={styles.th}>Status</th>
                  <th style={styles.th}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleDrivers.map((d) => (
                  <tr key={d._id} style={{ ...styles.tr, animation: 'fadeUp 0.28s ease-out', animationFillMode: 'both' }}>
                    <td style={styles.td}>{d.name}</td>
                    <td style={styles.td}>{d.email}</td>
                    <td style={styles.td}>{d.phone}</td>
                    <td style={styles.td}>{d.licenseNumber}</td>
                    <td style={styles.td}>{d.vehicleNumber}</td>
                    <td style={styles.td}>{d.area || '—'}</td>
                    <td style={styles.td}>{d.ratePerKm > 0 ? `LKR ${d.ratePerKm}` : '—'}</td>
                    <td style={styles.td}>
                      <span style={d.isVerified ? styles.badgeGreen : styles.badgeOrange}>
                        {d.isVerified ? 'Verified' : 'Pending'}
                      </span>
                    </td>
                    <td style={styles.td}>
                      {d.role !== 'regulator' && (
                        d.isVerified ? (
                          <button
                            style={styles.btnReject}
                            onClick={() => handleVerify(d._id, false)}
                          >
                            Reject
                          </button>
                        ) : (
                          <button
                            style={styles.btnApprove}
                            onClick={() => handleVerify(d._id, true)}
                          >
                            Approve
                          </button>
                        )
                      )}
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
  page: { minHeight: '100vh', background: 'linear-gradient(135deg, #f4f7ff 0%, #eef2f8 100%)' },
  nav: {
    background: 'linear-gradient(90deg, #1a1a2e 0%, #29314b 100%)',
    color: '#fff', padding: '0.9rem 2rem',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    boxShadow: '0 12px 24px rgba(15, 23, 62, 0.12)',
  },
  navTitle: { fontWeight: '800', fontSize: '1.1rem', letterSpacing: '0.02em' },
  navBtn: {
    background: 'none', border: 'none', color: '#fff',
    cursor: 'pointer', marginLeft: '1rem', fontSize: '0.95rem', transition: 'opacity 150ms ease',
  },
  content: { padding: '2rem', maxWidth: '1180px', margin: '0 auto' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', gap: '1rem', flexWrap: 'wrap' },
  headerActions: { display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' },
  pageTitle: { margin: 0, fontSize: '1.4rem', color: '#1a1a2e' },
  searchInput: {
    padding: '0.55rem 0.95rem', border: '1px solid #d2ddec', borderRadius: '10px', minWidth: '220px', outline: 'none', transition: 'box-shadow 180ms ease, border-color 180ms ease',
  },
  filterBtn: {
    padding: '0.5rem 1rem', border: '1px solid #d2ddec',
    borderRadius: '10px', cursor: 'pointer', background: '#fff', transition: 'transform 180ms ease, background 180ms ease, border-color 180ms ease',
  },
  filterActive: { background: '#22305a', color: '#fff', borderColor: '#22305a' },
  tableWrap: { overflowX: 'auto', background: '#fff', borderRadius: '16px', boxShadow: '0 16px 40px rgba(20, 35, 90, 0.08)', border: '1px solid rgba(206, 216, 240, 0.9)', animation: 'fadeUp 0.35s ease-out' },
  skeletonWrapper: { background: '#fff', borderRadius: '16px', border: '1px solid rgba(206, 216, 240, 0.9)', padding: '1rem', boxShadow: '0 16px 40px rgba(20, 35, 90, 0.06)', display: 'grid', gap: '0.85rem', animation: 'fadeUp 0.35s ease-out' },
  skeletonRow: { display: 'grid', gridTemplateColumns: 'repeat(9, minmax(0, 1fr))', gap: '0.75rem', alignItems: 'center' },
  skeletonCell: { height: '1rem', borderRadius: '999px', background: 'linear-gradient(90deg, #eef2ff 0%, #f6f8ff 50%, #eef2ff 100%)', animation: 'shimmer 1.6s ease-in-out infinite' },
  table: { width: '100%', borderCollapse: 'collapse', minWidth: '980px' },
  thead: { background: '#f4f7ff' },
  th: { padding: '0.85rem 1rem', textAlign: 'left', fontSize: '0.85rem', color: '#5d6b8b', borderBottom: '1px solid #eef1f8' },
  tr: { borderBottom: '1px solid #f2f4f8', background: '#fff' },
  td: { padding: '0.85rem 1rem', fontSize: '0.92rem', color: '#333' },
  badgeGreen: { background: '#d4edda', color: '#155724', padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  badgeOrange: { background: '#fff3cd', color: '#856404', padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  btnApprove: { background: '#27ae60', color: '#fff', border: 'none', padding: '0.35rem 0.8rem', borderRadius: '4px', cursor: 'pointer' },
  btnReject: { background: '#e74c3c', color: '#fff', border: 'none', padding: '0.35rem 0.8rem', borderRadius: '4px', cursor: 'pointer' },
  info: { color: '#888', textAlign: 'center', marginTop: '2rem' },
  error: { color: '#c0392b', textAlign: 'center', marginTop: '2rem' },
};
