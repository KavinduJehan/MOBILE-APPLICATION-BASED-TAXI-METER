import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Drivers() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState('all');
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
        <div style={styles.header}>
          <h2 style={styles.pageTitle}>Driver Management</h2>
          <div>
            {['all', 'pending', 'verified'].map((f) => (
              <button
                key={f}
                style={{ ...styles.filterBtn, ...(filter === f ? styles.filterActive : {}) }}
                onClick={() => setFilter(f)}
              >
                {f.charAt(0).toUpperCase() + f.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {loading && <p style={styles.info}>Loading...</p>}
        {error && <p style={styles.error}>{error}</p>}
        {!loading && !error && drivers.length === 0 && (
          <p style={styles.info}>No drivers found.</p>
        )}

        {!loading && drivers.length > 0 && (
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
                {drivers.map((d) => (
                  <tr key={d._id} style={styles.tr}>
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
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' },
  pageTitle: { margin: 0, fontSize: '1.4rem', color: '#1a1a2e' },
  filterBtn: {
    padding: '0.4rem 1rem', marginLeft: '0.5rem', border: '1px solid #ccc',
    borderRadius: '4px', cursor: 'pointer', background: '#fff',
  },
  filterActive: { background: '#1a1a2e', color: '#fff', borderColor: '#1a1a2e' },
  tableWrap: { overflowX: 'auto', background: '#fff', borderRadius: '8px', boxShadow: '0 1px 6px rgba(0,0,0,0.08)' },
  table: { width: '100%', borderCollapse: 'collapse' },
  thead: { background: '#f7f8fa' },
  th: { padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.85rem', color: '#555', borderBottom: '1px solid #eee' },
  tr: { borderBottom: '1px solid #f0f0f0' },
  td: { padding: '0.75rem 1rem', fontSize: '0.9rem', color: '#333' },
  badgeGreen: { background: '#d4edda', color: '#155724', padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  badgeOrange: { background: '#fff3cd', color: '#856404', padding: '0.2rem 0.6rem', borderRadius: '12px', fontSize: '0.8rem' },
  btnApprove: { background: '#27ae60', color: '#fff', border: 'none', padding: '0.35rem 0.8rem', borderRadius: '4px', cursor: 'pointer' },
  btnReject: { background: '#e74c3c', color: '#fff', border: 'none', padding: '0.35rem 0.8rem', borderRadius: '4px', cursor: 'pointer' },
  info: { color: '#888', textAlign: 'center', marginTop: '2rem' },
  error: { color: '#c0392b', textAlign: 'center', marginTop: '2rem' },
};
