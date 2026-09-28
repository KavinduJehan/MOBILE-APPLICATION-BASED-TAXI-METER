import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

// Sri Lankan city tiers for reference
const AREA_TIERS = {
  'Tier A — High demand (×1.15)': ['Colombo', 'Kandy', 'Galle'],
  'Tier B — Moderate (×1.05)':    ['Negombo', 'Kurunegala', 'Ratnapura'],
  'Tier C — Low / rural (×1.00)': ['All other areas'],
};

const MODE_INFO = {
  DRIVER: {
    title: 'Driver sets rate',
    desc: 'Each driver types their own rate per km. No algorithm involved.',
    color: '#27ae60',
    icon: '🧑‍✈️',
  },
  ADMIN: {
    title: 'Admin fixed rate',
    desc: 'Drivers cannot change their rate. A fixed value is controlled by regulators.',
    color: '#6c7cff',
    icon: '🔒',
  },
  AUTO: {
    title: 'Auto surge pricing',
    desc: 'Algorithm calculates each rate in real time using demand, time of day, weather and area tier.',
    color: '#f39c12',
    icon: '⚡',
  },
};

export default function Pricing() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');
  const [success, setSuccess] = useState('');

  // Editable fields
  const [rateMode,        setRateMode]        = useState('ADMIN');
  const [autoBaseRate,    setAutoBaseRate]     = useState(100);
  const [autoMinMult,     setAutoMinMult]      = useState(1.0);
  const [autoMaxMult,     setAutoMaxMult]      = useState(2.5);
  const [previewLoading,  setPreviewLoading]   = useState(false);
  const [preview,         setPreview]          = useState(null);
  const [previewArea,     setPreviewArea]      = useState('Colombo');

  useEffect(() => {
    api.get('/admin/config').then((res) => {
      const c = res.data;
      setRateMode(c.rateMode       || 'ADMIN');
      setAutoBaseRate(c.autoBaseRate    ?? 100);
      setAutoMinMult (c.autoMinMultiplier ?? 1.0);
      setAutoMaxMult (c.autoMaxMultiplier ?? 2.5);
    }).catch(() => setError('Failed to load config.')).finally(() => setLoading(false));
  }, []);

  const handleSave = async () => {
    setSaving(true); setError(''); setSuccess('');
    try {
      await api.patch('/admin/config', {
        rateMode,
        autoBaseRate:    Number(autoBaseRate),
        autoMinMultiplier: Number(autoMinMult),
        autoMaxMultiplier: Number(autoMaxMult),
      });
      setSuccess('Pricing settings saved.');
    } catch (err) {
      setError(err.response?.data?.message || 'Save failed.');
    } finally { setSaving(false); }
  };

  const handlePreview = async () => {
    setPreviewLoading(true); setPreview(null);
    try {
      const res = await api.get(`/rates/auto?area=${encodeURIComponent(previewArea)}`);
      setPreview(res.data);
    } catch { setPreview({ error: 'Preview unavailable' }); }
    finally { setPreviewLoading(false); }
  };

  const handleLogout = () => { localStorage.removeItem('adminToken'); navigate('/login'); };

  if (loading) return <div style={s.page}><p style={s.muted}>Loading…</p></div>;

  return (
    <div style={s.page}>
      <style>{`
        @keyframes fadeUp { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }
        .mode-card:hover { transform: translateY(-2px); box-shadow: 0 12px 28px rgba(0,0,0,0.10); }
      `}</style>

      {/* nav */}
      <nav style={s.nav}>
        <span style={s.navTitle}>Taxi Meter Admin</span>
        <div>
          <button style={s.navBtn} onClick={() => navigate('/dashboard')}>Dashboard</button>
          <button style={s.navBtn} onClick={() => navigate('/drivers')}>Drivers</button>
          <button style={s.navBtn} onClick={() => navigate('/trips')}>Trips</button>
          <button style={s.navBtn} onClick={() => navigate('/pricing')}>Pricing</button>
          <button style={{...s.navBtn, color:'#e74c3c'}} onClick={handleLogout}>Logout</button>
        </div>
      </nav>

      <div style={s.content}>
        <h2 style={s.pageTitle}>Pricing Settings</h2>
        <p style={s.subtitle}>Set the default pricing method for new drivers and configure shared Auto Surge Pricing. Assign or change a method for each driver in Driver Management.</p>

        {error   && <div style={s.alertErr}>{error}</div>}
        {success && <div style={s.alertOk}>{success}</div>}

        {/* ── Mode selector ─────────────────────────────────── */}
        <div style={s.section}>
          <h3 style={s.sectionTitle}>Rate mode</h3>
          <div style={s.modeGrid}>
            {Object.entries(MODE_INFO).map(([mode, info]) => {
              const active = rateMode === mode;
              return (
                <div
                  key={mode}
                  className="mode-card"
                  onClick={() => setRateMode(mode)}
                  style={{
                    ...s.modeCard,
                    borderColor: active ? info.color : 'rgba(0,0,0,0.08)',
                    background:  active ? `${info.color}12` : '#fff',
                    boxShadow:   active ? `0 0 0 2px ${info.color}` : '0 4px 14px rgba(0,0,0,0.05)',
                  }}
                >
                  <div style={s.modeIcon}>{info.icon}</div>
                  <div style={{...s.modeLabel, color: active ? info.color : '#1a1a2e'}}>{info.title}</div>
                  <div style={s.modeDesc}>{info.desc}</div>
                  {active && <div style={{...s.modeBadge, background: info.color}}>Active</div>}
                </div>
              );
            })}
          </div>
        </div>

        {/* ── AUTO config (only when AUTO is selected) ──────── */}
        {rateMode === 'AUTO' && (
          <div style={{...s.section, animation: 'fadeUp 0.3s ease-out'}}>
            <h3 style={s.sectionTitle}>⚡ Algorithm parameters</h3>
            <div style={s.paramGrid}>
              <label style={s.paramLabel}>
                Base rate (LKR / km)
                <input
                  type="number" min="1" step="5"
                  value={autoBaseRate}
                  onChange={(e) => setAutoBaseRate(e.target.value)}
                  style={s.input}
                />
                <span style={s.hint}>The rate before the surge multiplier is applied.</span>
              </label>
              <label style={s.paramLabel}>
                Min multiplier
                <input
                  type="number" min="1.0" max="5.0" step="0.1"
                  value={autoMinMult}
                  onChange={(e) => setAutoMinMult(e.target.value)}
                  style={s.input}
                />
                <span style={s.hint}>Lowest possible surge (1.0 = no discount below base).</span>
              </label>
              <label style={s.paramLabel}>
                Max multiplier
                <input
                  type="number" min="1.0" max="5.0" step="0.1"
                  value={autoMaxMult}
                  onChange={(e) => setAutoMaxMult(e.target.value)}
                  style={s.input}
                />
                <span style={s.hint}>Highest surge cap (Uber uses 2.5 by default).</span>
              </label>
            </div>

            {/* Area tiers info */}
            <div style={s.tiersBox}>
              <div style={s.tiersTitle}>Area tiers (fixed — editable via API)</div>
              {Object.entries(AREA_TIERS).map(([tier, cities]) => (
                <div key={tier} style={s.tierRow}>
                  <span style={s.tierLabel}>{tier}</span>
                  <span style={s.tierCities}>{cities.join(', ')}</span>
                </div>
              ))}
            </div>

            {/* Live preview */}
            <div style={s.previewBox}>
              <div style={s.sectionTitle}>🔍 Live rate preview</div>
              <div style={s.previewRow}>
                <input
                  value={previewArea}
                  onChange={(e) => setPreviewArea(e.target.value)}
                  placeholder="Enter area, e.g. Colombo"
                  style={{...s.input, flex: 1, marginBottom: 0}}
                />
                <button
                  onClick={handlePreview}
                  disabled={previewLoading}
                  style={s.previewBtn}
                >
                  {previewLoading ? 'Calculating…' : 'Calculate now'}
                </button>
              </div>
              {preview && !preview.error && (
                <div style={s.previewResult}>
                  <div style={s.previewRate}>
                    Rs. {preview.effectiveRate?.toFixed(2)} / km
                    <span style={s.previewMult}> ({preview.multiplier?.toFixed(2)}× surge)</span>
                  </div>
                  <div style={s.breakdownGrid}>
                    {[
                      ['🚗 Demand/supply', `${preview.breakdown?.availableDrivers} drivers · ${preview.breakdown?.activeRequests} requests`, preview.breakdown?.demandSupplyFactor],
                      ['🕐 Time of day', new Date().toLocaleTimeString(), preview.breakdown?.timeFactor],
                      ['🌦 Weather', preview.breakdown?.weatherCondition, preview.breakdown?.weatherFactor],
                      ['📍 Area tier', preview.area, preview.breakdown?.areaFactor],
                    ].map(([label, detail, factor]) => (
                      <div key={label} style={s.breakdownCell}>
                        <div style={s.bLabel}>{label}</div>
                        <div style={s.bDetail}>{detail}</div>
                        <div style={{...s.bFactor, color: factor >= 1.3 ? '#f39c12' : '#27ae60'}}>
                          {Number(factor).toFixed(2)}×
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              {preview?.error && <p style={s.alertErr}>{preview.error}</p>}
            </div>
          </div>
        )}

        {/* ── Weights reference (always visible) ────────────── */}
        <div style={s.section}>
          <h3 style={s.sectionTitle}>Algorithm signal weights</h3>
          <div style={s.weightsGrid}>
            {[
              ['🚗', 'Demand / supply', '50%', 'Active ride requests ÷ available verified drivers in area'],
              ['🕐', 'Time of day',     '25%', 'Morning rush (7–9 AM), evening rush (5–8 PM), late night (10 PM–2 AM)'],
              ['🌦', 'Weather',         '15%', 'OpenWeatherMap: Rain=1.3×, Thunderstorm=1.5×, Clear=1.0×'],
              ['📍', 'Area tier',       '10%', 'Tier A cities get 1.15×, Tier B 1.05×, others 1.0×'],
            ].map(([icon, name, weight, desc]) => (
              <div key={name} style={s.weightCard}>
                <div style={s.weightTop}>
                  <span style={s.wIcon}>{icon}</span>
                  <span style={s.wName}>{name}</span>
                  <span style={s.wBadge}>{weight}</span>
                </div>
                <p style={s.wDesc}>{desc}</p>
              </div>
            ))}
          </div>
        </div>

        <button onClick={handleSave} disabled={saving} style={s.saveBtn}>
          {saving ? 'Saving…' : 'Save settings'}
        </button>
      </div>
    </div>
  );
}

const s = {
  page: { minHeight: '100vh', background: 'linear-gradient(135deg, #f4f7ff 0%, #edf0ff 100%)', fontFamily: 'Inter, Segoe UI, sans-serif' },
  nav:  { background: 'linear-gradient(90deg,#1a1a2e,#27314d)', color: '#fff', padding: '0.9rem 2rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between', boxShadow: '0 8px 24px rgba(26,26,46,.18)' },
  navTitle: { fontWeight: 800, fontSize: '1.1rem' },
  navBtn:   { background: 'none', border: 'none', color: '#fff', cursor: 'pointer', marginLeft: '1rem', fontSize: '0.95rem' },
  content:  { padding: '2rem', maxWidth: '1100px', margin: '0 auto' },
  pageTitle: { fontSize: '1.5rem', color: '#1a1a2e', margin: 0 },
  subtitle:  { color: '#68708a', marginTop: '0.3rem', marginBottom: '1.5rem' },
  section:   { background: '#fff', borderRadius: '18px', padding: '1.4rem 1.6rem', marginBottom: '1.2rem', boxShadow: '0 8px 22px rgba(23,34,71,.07)', border: '1px solid rgba(108,124,255,.1)' },
  sectionTitle: { margin: '0 0 1rem', fontSize: '1rem', color: '#1a1a2e', fontWeight: 700 },
  modeGrid:  { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px,1fr))', gap: '1rem' },
  modeCard:  { borderRadius: '14px', border: '2px solid', padding: '1.2rem', cursor: 'pointer', transition: 'all .2s ease', position: 'relative' },
  modeIcon:  { fontSize: '1.8rem', marginBottom: '0.5rem' },
  modeLabel: { fontWeight: 700, fontSize: '1rem', marginBottom: '0.35rem' },
  modeDesc:  { color: '#68708a', fontSize: '0.84rem', lineHeight: 1.4 },
  modeBadge: { position: 'absolute', top: '0.7rem', right: '0.7rem', color: '#fff', fontSize: '0.72rem', fontWeight: 700, padding: '0.2rem 0.55rem', borderRadius: '999px' },
  paramGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px,1fr))', gap: '1rem', marginBottom: '1.2rem' },
  paramLabel: { display: 'flex', flexDirection: 'column', gap: '0.4rem', fontSize: '0.88rem', color: '#333', fontWeight: 600 },
  input:  { padding: '0.55rem 0.85rem', border: '1px solid #d2ddec', borderRadius: '10px', fontSize: '0.9rem', outline: 'none', marginBottom: '0.2rem' },
  hint:   { color: '#8a96b0', fontSize: '0.78rem', fontWeight: 400 },
  tiersBox: { background: '#f8fafe', borderRadius: '12px', padding: '1rem 1.2rem', marginBottom: '1.2rem' },
  tiersTitle: { fontWeight: 700, fontSize: '0.85rem', color: '#5b6cff', marginBottom: '0.6rem' },
  tierRow:    { display: 'flex', gap: '1rem', paddingBottom: '0.4rem', fontSize: '0.85rem' },
  tierLabel:  { color: '#1a1a2e', fontWeight: 600, minWidth: '230px' },
  tierCities: { color: '#68708a' },
  previewBox:  { background: '#f8fafe', borderRadius: '14px', padding: '1rem 1.2rem' },
  previewRow:  { display: 'flex', gap: '0.75rem', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap' },
  previewBtn:  { background: 'linear-gradient(135deg,#1a1a2e,#27314d)', color: '#fff', border: 'none', padding: '0.6rem 1.1rem', borderRadius: '10px', cursor: 'pointer', whiteSpace: 'nowrap', fontWeight: 600 },
  previewResult: { background: '#fff', borderRadius: '12px', padding: '1rem' },
  previewRate: { fontSize: '1.5rem', fontWeight: 800, color: '#1a1a2e', marginBottom: '0.8rem' },
  previewMult: { fontSize: '1rem', color: '#f39c12' },
  breakdownGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px,1fr))', gap: '0.75rem' },
  breakdownCell: { background: '#f8fafe', borderRadius: '10px', padding: '0.7rem' },
  bLabel:  { fontWeight: 700, fontSize: '0.8rem', color: '#1a1a2e', marginBottom: '0.2rem' },
  bDetail: { color: '#68708a', fontSize: '0.78rem', marginBottom: '0.3rem' },
  bFactor: { fontWeight: 800, fontSize: '1rem' },
  weightsGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px,1fr))', gap: '0.85rem' },
  weightCard: { background: '#f8fafe', borderRadius: '12px', padding: '0.9rem 1rem' },
  weightTop:  { display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.4rem' },
  wIcon:  { fontSize: '1.3rem' },
  wName:  { fontWeight: 700, color: '#1a1a2e', fontSize: '0.9rem', flex: 1 },
  wBadge: { background: '#e8edff', color: '#5b6cff', padding: '0.15rem 0.5rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 700 },
  wDesc:  { color: '#68708a', fontSize: '0.8rem', margin: 0, lineHeight: 1.4 },
  saveBtn: { background: 'linear-gradient(135deg,#6c7cff,#3c57ff)', color: '#fff', border: 'none', padding: '0.8rem 2rem', borderRadius: '12px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', boxShadow: '0 8px 20px rgba(60,87,255,.25)', marginTop: '0.5rem' },
  alertErr: { background: '#fdecea', color: '#c0392b', borderRadius: '10px', padding: '0.7rem 1rem', marginBottom: '1rem', fontSize: '0.9rem' },
  alertOk:  { background: '#eafaf1', color: '#1e8449', borderRadius: '10px', padding: '0.7rem 1rem', marginBottom: '1rem', fontSize: '0.9rem' },
  muted: { color: '#888', padding: '2rem' },
};
