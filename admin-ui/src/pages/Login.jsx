import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Login() {
  const [mode, setMode] = useState('login'); // 'login' | 'first-login-change' | 'forgot' | 'reset'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [debugCode, setDebugCode] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setLoading(true);
    try {
      const res = await api.post('/auth/login', { email, password });
      const { token, driver } = res.data;
      if (driver.role !== 'regulator') {
        setError('Access denied. Admin accounts only.');
        setLoading(false);
        return;
      }
      localStorage.setItem('adminToken', token);
      if (driver.requiresPasswordChange) {
        setMode('first-login-change');
        setPassword('');
        setMessage('Set a new password to finish securing your admin account.');
      } else {
        navigate('/drivers');
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleFirstLoginPasswordChange = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (newPassword.length < 12) {
      setError('Password must be at least 12 characters');
      return;
    }

    setLoading(true);
    try {
      await api.put('/admin/change-password', { newPassword });
      setNewPassword('');
      setConfirmPassword('');
      navigate('/drivers');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to change password');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setLoading(true);
    try {
      const res = await api.post('/auth/forgot-password', { email });
      setMessage(res.data?.message || 'Verification code sent to your email.');
      if (res.data?.debugCode) {
        setDebugCode(res.data.debugCode);
      }
      setMode('reset');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to send reset code');
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');

    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (newPassword.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post('/auth/reset-password', {
        email,
        code,
        newPassword,
      });
      setMessage(res.data?.message || 'Password reset successful. Please sign in.');
      setMode('login');
      setPassword('');
      setCode('');
      setNewPassword('');
      setConfirmPassword('');
      setDebugCode('');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to reset password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h2 style={styles.title}>Taxi Meter — Admin</h2>
        
        {mode === 'first-login-change' && (
          <>
            <p style={styles.subtitle}>Choose a new password before continuing. Use at least 12 characters.</p>
            {message && <p style={styles.success}>{message}</p>}
            <form onSubmit={handleFirstLoginPasswordChange}>
              <div style={styles.field}>
                <label style={styles.label}>New Password</label>
                <input style={styles.input} type="password" value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)} required minLength={12} autoFocus />
              </div>
              <div style={styles.field}>
                <label style={styles.label}>Confirm New Password</label>
                <input style={styles.input} type="password" value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)} required minLength={12} />
              </div>
              {error && <p style={styles.error}>{error}</p>}
              <button style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
                type="submit" disabled={loading}>
                {loading ? 'Changing Password...' : 'Set New Password'}
              </button>
            </form>
          </>
        )}

        {mode === 'login' && (
          <>
            <p style={styles.subtitle}>Sign in with your regulator account to continue.</p>
            {message && <p style={styles.success}>{message}</p>}
            <form onSubmit={handleLogin}>
              <div style={styles.field}>
                <label style={styles.label}>Email</label>
                <input
                  style={styles.input} 
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoFocus
                />
              </div>
              <div style={styles.field}>
                <div style={styles.labelRow}>
                  <label style={styles.label}>Password</label>
                  <button
                    type="button"
                    style={styles.linkButton}
                    onClick={() => {
                      setError('');
                      setMessage('');
                      setMode('forgot');
                    }}
                  >
                    Forgot password?
                  </button>
                </div>
                <input
                  style={styles.input}
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
              {error && <p style={styles.error}>{error}</p>}
              <button
                style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
                type="submit"
                disabled={loading}
              >
                {loading ? 'Signing in...' : 'Sign In'}
              </button>
            </form>
          </>
        )}

        {mode === 'forgot' && (
          <>
            <p style={styles.subtitle}>Enter your email to receive a 6-digit verification code.</p>
            <form onSubmit={handleForgotPassword}>
              <div style={styles.field}>
                <label style={styles.label}>Email</label>
                <input
                  style={styles.input} 
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoFocus
                />
              </div>
              {error && <p style={styles.error}>{error}</p>}
              <button
                style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
                type="submit"
                disabled={loading}
              >
                {loading ? 'Sending Code...' : 'Send Verification Code'}
              </button>
              <div style={styles.centerAction}>
                <button
                  type="button"
                  style={styles.textLink}
                  onClick={() => {
                    setError('');
                    setMessage('');
                    setMode('login');
                  }}
                >
                  ← Back to Sign In
                </button>
              </div>
            </form>
          </>
        )}

        {mode === 'reset' && (
          <>
            <p style={styles.subtitle}>Enter the 6-digit code sent to {email} and choose a new password.</p>
            {message && <p style={styles.success}>{message}</p>}
            {debugCode && (
              <div style={styles.debugBox}>
                <strong>Development Code:</strong> {debugCode}
              </div>
            )}
            <form onSubmit={handleResetPassword}>
              <div style={styles.field}>
                <label style={styles.label}>6-Digit Code</label>
                <input
                  style={styles.input} 
                  type="text"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value.trim())}
                  required
                  autoFocus
                />
              </div>
              <div style={styles.field}>
                <label style={styles.label}>New Password</label>
                <input
                  style={styles.input} 
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  required
                  minLength={6}
                />
              </div>
              <div style={styles.field}>
                <label style={styles.label}>Confirm New Password</label>
                <input
                  style={styles.input} 
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  minLength={6}
                />
              </div>
              {error && <p style={styles.error}>{error}</p>}
              <button
                style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
                type="submit"
                disabled={loading}
              >
                {loading ? 'Resetting Password...' : 'Reset Password'}
              </button>
              <div style={styles.centerAction}>
                <button
                  type="button"
                  style={styles.textLink}
                  onClick={() => {
                    setError('');
                    setMessage('');
                    setMode('forgot');
                  }}
                >
                  Request another code
                </button>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#f0f2f5',
  },
  card: {
    background: '#fff',
    padding: '2.5rem',
    borderRadius: '8px',
    boxShadow: '0 2px 12px rgba(0,0,0,0.1)',
    width: '100%',
    maxWidth: '420px',
  },
  title: {
    marginBottom: '1.5rem',
    fontSize: '1.4rem',
    textAlign: 'center',
    color: '#1a1a2e',
  },
  subtitle: {
    marginTop: '-0.75rem',
    marginBottom: '1.25rem',
    fontSize: '0.9rem',
    textAlign: 'center',
    color: '#5b6078',
    lineHeight: 1.4,
  },
  field: { marginBottom: '1rem' },
  labelRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '0.3rem',
  },
  label: { display: 'block', marginBottom: '0.3rem', fontSize: '0.9rem', color: '#555' },
  linkButton: {
    background: 'none',
    border: 'none',
    color: '#2563eb',
    fontSize: '0.82rem',
    cursor: 'pointer',
    padding: 0,
    textDecoration: 'underline',
  },
  input: {
    width: '100%',
    padding: '0.6rem 0.8rem',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '1rem',
    boxSizing: 'border-box',
  },
  button: {
    width: '100%',
    padding: '0.75rem',
    background: '#1a1a2e',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '1rem',
    cursor: 'pointer',
    marginTop: '0.5rem',
  },
  buttonDisabled: {
    opacity: 0.75,
    cursor: 'not-allowed',
  },
  error: { color: '#c0392b', fontSize: '0.9rem', marginBottom: '0.5rem' },
  success: { color: '#16a34a', fontSize: '0.9rem', marginBottom: '0.8rem', textAlign: 'center' },
  debugBox: {
    padding: '0.5rem 0.75rem',
    marginBottom: '1rem',
    background: '#eff6ff',
    border: '1px solid #bfdbfe',
    borderRadius: '4px',
    fontSize: '0.85rem',
    color: '#1d4ed8',
    textAlign: 'center',
  },
  centerAction: {
    textAlign: 'center',
    marginTop: '1rem',
  },
  textLink: {
    background: 'none',
    border: 'none',
    color: '#5b6078',
    fontSize: '0.88rem',
    cursor: 'pointer',
  },
};
