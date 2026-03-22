import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { colors } from '../components/shared/theme';
import { ErrorMessage } from '../components/shared/Feedback';

const DEMO_ACCOUNTS = [
  { label: 'Super Admin', username: 'superadmin', password: 'admin123', color: '#ef4444' },
  { label: 'Admin',       username: 'admin',      password: 'admin123', color: '#f97316' },
  { label: 'Manager',     username: 'manager1',   password: 'manager123', color: '#3b82f6' },
  { label: 'Staff',       username: 'staff1',     password: 'staff123',   color: '#10b981' },
];

export default function LoginPage() {
  const { login } = useAuth();
  const navigate  = useNavigate();

  const [form,    setForm]    = useState({ username: '', password: '' });
  const [showPw,  setShowPw]  = useState(false);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState('');

  const handleChange = (e) => {
    setForm((p) => ({ ...p, [e.target.name]: e.target.value }));
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await login(form);
      navigate('/dashboard');
    } catch (err) {
      setError(err?.response?.data?.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const inputStyle = {
    width: '100%', padding: '10px 14px', borderRadius: 10,
    border: `1.5px solid ${colors.border}`, fontSize: 15,
    color: colors.dark, background: colors.white, outline: 'none',
    boxSizing: 'border-box', fontFamily: 'inherit',
  };

  return (
    <div style={{
      minHeight: '100vh', background: 'linear-gradient(135deg, #f0f4ff 0%, #f8faff 50%, #f5f0ff 100%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '1rem', fontFamily: "'DM Sans', sans-serif",
    }}>
      <div style={{ width: '100%', maxWidth: 420 }}>
        {/* ── Logo ── */}
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            width: 64, height: 64, borderRadius: 18,
            background: `linear-gradient(135deg, ${colors.primary}, ${colors.accent})`,
            fontSize: 28, marginBottom: 12, boxShadow: '0 8px 24px rgba(99,102,241,0.3)',
          }}>✂️</div>
          <h1 style={{
            fontFamily: "'Cormorant Garamond', serif",
            fontSize: 36, fontWeight: 700, color: colors.dark,
            margin: 0, letterSpacing: 1,
          }}>LuxeSalon</h1>
          <p style={{ color: colors.muted, margin: '6px 0 0', fontSize: 14 }}>Salon Management System</p>
        </div>

        {/* ── Card ── */}
        <div style={{
          background: colors.white, borderRadius: 20,
          boxShadow: '0 8px 40px rgba(0,0,0,0.10)',
          padding: '2rem',
        }}>
          <h2 style={{ margin: '0 0 1.5rem', fontSize: 20, fontWeight: 700, color: colors.dark }}>Sign In</h2>

          {error && <div style={{ marginBottom: '1rem' }}><ErrorMessage message={error} /></div>}

          <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: colors.muted, marginBottom: 6 }}>Username</label>
              <input name="username" value={form.username} onChange={handleChange}
                placeholder="Enter username" autoFocus
                style={inputStyle} required />
            </div>

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: colors.muted, marginBottom: 6 }}>Password</label>
              <div style={{ position: 'relative' }}>
                <input name="password" value={form.password} onChange={handleChange}
                  type={showPw ? 'text' : 'password'} placeholder="Enter password"
                  style={{ ...inputStyle, paddingRight: 44 }} required />
                <button type="button" onClick={() => setShowPw(!showPw)}
                  style={{
                    position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                    background: 'none', border: 'none', cursor: 'pointer', color: colors.muted, fontSize: 16,
                  }}>
                  {showPw ? '🙈' : '👁'}
                </button>
              </div>
            </div>

            <button type="submit" disabled={loading}
              style={{
                width: '100%', padding: '12px', borderRadius: 10, border: 'none',
                background: loading ? colors.border : `linear-gradient(135deg, ${colors.primary}, ${colors.accent})`,
                color: loading ? colors.muted : '#fff', fontSize: 15, fontWeight: 700,
                cursor: loading ? 'not-allowed' : 'pointer', transition: 'all .2s',
                fontFamily: 'inherit',
              }}>
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>

        {/* ── Demo accounts ── */}
        <div style={{
          background: colors.white, borderRadius: 16,
          boxShadow: '0 4px 20px rgba(0,0,0,0.06)',
          padding: '1.25rem', marginTop: '1rem',
        }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: colors.muted, marginBottom: 10, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Demo Accounts — click to fill
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {DEMO_ACCOUNTS.map((a) => (
              <button key={a.username}
                type="button"
                onClick={() => { setForm({ username: a.username, password: a.password }); setError(''); }}
                style={{
                  padding: '5px 12px', borderRadius: 8, border: `1.5px solid ${a.color}20`,
                  background: a.color + '12', color: a.color, fontWeight: 600, fontSize: 12,
                  cursor: 'pointer', fontFamily: 'inherit', transition: 'all .15s',
                }}>
                {a.label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
