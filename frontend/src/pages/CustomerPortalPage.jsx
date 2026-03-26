import { useMemo, useState } from 'react';

const cardStyle = {
  background: '#fff',
  border: '1px solid #e5e7eb',
  borderRadius: 12,
  padding: 16,
};

const inputStyle = {
  width: '100%',
  padding: '10px 12px',
  borderRadius: 8,
  border: '1px solid #d1d5db',
  outline: 'none',
};

const btnStyle = {
  border: 'none',
  borderRadius: 8,
  padding: '10px 14px',
  background: '#111827',
  color: '#fff',
  cursor: 'pointer',
  fontWeight: 600,
};

export default function CustomerPortalPage() {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [portalToken, setPortalToken] = useState(localStorage.getItem('portal_token') || '');
  const [profile, setProfile] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [debugOtp, setDebugOtp] = useState('');
  const [rebookDraft, setRebookDraft] = useState({ appointmentId: null, date: '', time: '' });

  const api = useMemo(() => ({
    async requestOtp() {
      const res = await fetch('/api/public/customer-portal/request-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone }),
      });
      return res.json();
    },
    async verifyOtp() {
      const res = await fetch('/api/public/customer-portal/verify-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, otp }),
      });
      return { ok: res.ok, data: await res.json() };
    },
    async me(token) {
      const res = await fetch('/api/public/customer-portal/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      return { ok: res.ok, data: await res.json() };
    },
    async bookings(token) {
      const res = await fetch('/api/public/customer-portal/bookings', {
        headers: { Authorization: `Bearer ${token}` },
      });
      return { ok: res.ok, data: await res.json() };
    },
    async rebook(token, payload) {
      const res = await fetch('/api/public/customer-portal/rebook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });
      return { ok: res.ok, data: await res.json() };
    },
  }), [phone, otp]);

  const loadPortalData = async (token) => {
    const [meRes, bookingsRes] = await Promise.all([api.me(token), api.bookings(token)]);
    if (!meRes.ok || !bookingsRes.ok) {
      setMessage(meRes.data?.message || bookingsRes.data?.message || 'Failed to load portal data.');
      return;
    }
    setProfile(meRes.data);
    setBookings(Array.isArray(bookingsRes.data) ? bookingsRes.data : []);
  };

  const onRequestOtp = async () => {
    setLoading(true);
    setMessage('');
    setDebugOtp('');
    try {
      const data = await api.requestOtp();
      setMessage(data.message || 'OTP sent.');
      if (data.debug_otp) setDebugOtp(data.debug_otp);
    } catch (_err) {
      setMessage('Failed to request OTP.');
    } finally {
      setLoading(false);
    }
  };

  const onVerifyOtp = async () => {
    setLoading(true);
    setMessage('');
    try {
      const { ok, data } = await api.verifyOtp();
      if (!ok || !data.token) {
        setMessage(data.message || 'OTP verification failed.');
        return;
      }
      localStorage.setItem('portal_token', data.token);
      setPortalToken(data.token);
      setMessage('Login successful.');
      await loadPortalData(data.token);
    } catch (_err) {
      setMessage('Failed to verify OTP.');
    } finally {
      setLoading(false);
    }
  };

  const onLoadExistingSession = async () => {
    if (!portalToken) return;
    setLoading(true);
    setMessage('');
    try {
      await loadPortalData(portalToken);
    } finally {
      setLoading(false);
    }
  };

  const onRebook = async () => {
    if (!rebookDraft.appointmentId || !rebookDraft.date || !rebookDraft.time) {
      setMessage('Please select a booking, date, and time for rebooking.');
      return;
    }
    setLoading(true);
    try {
      const { ok, data } = await api.rebook(portalToken, rebookDraft);
      setMessage(data.message || (ok ? 'Rebook submitted.' : 'Rebook failed.'));
      if (ok) {
        setRebookDraft({ appointmentId: null, date: '', time: '' });
        await loadPortalData(portalToken);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 1000, margin: '0 auto', padding: 20 }}>
      <h1 style={{ marginBottom: 8 }}>Customer Portal</h1>
      <p style={{ marginTop: 0, color: '#4b5563' }}>
        View booking history, loyalty points, and rebook in one click.
      </p>

      <div style={{ ...cardStyle, marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>Login with Phone OTP</h3>
        <div style={{ display: 'grid', gap: 10, maxWidth: 400 }}>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Phone number"
            style={inputStyle}
          />
          <button onClick={onRequestOtp} style={btnStyle} disabled={loading || !phone}>
            Request OTP
          </button>
          <input
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            placeholder="Enter OTP"
            style={inputStyle}
          />
          <button onClick={onVerifyOtp} style={btnStyle} disabled={loading || !phone || !otp}>
            Verify OTP
          </button>
          {!!portalToken && (
            <button onClick={onLoadExistingSession} style={btnStyle} disabled={loading}>
              Load My Portal
            </button>
          )}
          {!!debugOtp && <small style={{ color: '#6b7280' }}>Dev OTP: {debugOtp}</small>}
        </div>
      </div>

      {!!message && <div style={{ ...cardStyle, marginBottom: 16 }}>{message}</div>}

      {profile && (
        <div style={{ ...cardStyle, marginBottom: 16 }}>
          <h3 style={{ marginTop: 0 }}>My Profile</h3>
          <p style={{ margin: '4px 0' }}><strong>Name:</strong> {profile.name}</p>
          <p style={{ margin: '4px 0' }}><strong>Phone:</strong> {profile.phone}</p>
          <p style={{ margin: '4px 0' }}><strong>Loyalty Points:</strong> {profile.loyalty_points}</p>
        </div>
      )}

      {profile && (
        <div style={{ ...cardStyle, marginBottom: 16 }}>
          <h3 style={{ marginTop: 0 }}>One-Click Rebook</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr auto', gap: 8 }}>
            <select
              value={rebookDraft.appointmentId || ''}
              onChange={(e) => setRebookDraft((d) => ({ ...d, appointmentId: Number(e.target.value) || null }))}
              style={inputStyle}
            >
              <option value="">Select past booking</option>
              {bookings.map((b) => (
                <option key={b.id} value={b.id}>
                  #{b.id} - {b.date} {String(b.time || '').slice(0, 5)} - {b.service?.name || 'Service'}
                </option>
              ))}
            </select>
            <input
              type="date"
              value={rebookDraft.date}
              onChange={(e) => setRebookDraft((d) => ({ ...d, date: e.target.value }))}
              style={inputStyle}
            />
            <input
              type="time"
              value={rebookDraft.time}
              onChange={(e) => setRebookDraft((d) => ({ ...d, time: e.target.value }))}
              style={inputStyle}
            />
            <button onClick={onRebook} style={btnStyle} disabled={loading}>Rebook</button>
          </div>
        </div>
      )}

      {profile && (
        <div style={cardStyle}>
          <h3 style={{ marginTop: 0 }}>My Booking History</h3>
          {!bookings.length && <p style={{ color: '#6b7280' }}>No bookings found.</p>}
          {bookings.map((b) => (
            <div key={b.id} style={{ borderTop: '1px solid #f3f4f6', padding: '10px 0' }}>
              <div><strong>{b.service?.name || 'Service'}</strong> - {b.status}</div>
              <div style={{ color: '#4b5563', fontSize: 14 }}>
                {b.date} {String(b.time || '').slice(0, 5)} | {b.branch?.name || '-'} | {b.staff?.name || 'Any staff'}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
