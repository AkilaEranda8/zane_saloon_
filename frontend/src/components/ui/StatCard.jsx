import { useState } from 'react';

function hexToRgba(hex, alpha) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

function TrendBadge({ value }) {
  const positive = value > 0;
  return (
    <span style={{
      display:     'inline-flex',
      alignItems:  'center',
      gap:         3,
      padding:     '2px 8px',
      borderRadius: 9999,
      fontSize:    12,
      fontWeight:  600,
      background:  positive ? '#D1FAE5' : '#FEE2E2',
      color:       positive ? '#059669' : '#DC2626',
      fontFamily:  "'Inter', sans-serif",
    }}>
      {positive ? '↑' : '↓'} {Math.abs(value)}%
    </span>
  );
}

export default function StatCard({ label, value, sub, icon, accent = '#2563EB', trend }) {
  const [hov, setHov] = useState(false);
  const iconBg = accent.startsWith('#') ? hexToRgba(accent, 0.12) : accent;

  return (
    <div
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      style={{
        background:   '#fff',
        border:       '1px solid #EAECF0',
        borderRadius: 14,
        padding:      20,
        boxShadow:    hov
          ? '0 4px 8px -2px rgba(16,24,40,.10), 0 2px 4px -2px rgba(16,24,40,.06)'
          : '0 1px 3px rgba(16,24,40,.10), 0 1px 2px rgba(16,24,40,.06)',
        transition:   'box-shadow 0.2s, transform 0.2s',
        transform:    hov ? 'translateY(-1px)' : 'none',
        fontFamily:   "'Inter', sans-serif",
      }}
    >
      {/* Top row: icon + trend */}
      <div style={{
        display:        'flex',
        alignItems:     'flex-start',
        justifyContent: 'space-between',
        marginBottom:   14,
        minHeight:      40,
      }}>
        {icon ? (
          <div style={{
            width:          40,
            height:         40,
            borderRadius:   10,
            background:     iconBg,
            display:        'flex',
            alignItems:     'center',
            justifyContent: 'center',
            color:          accent,
            flexShrink:     0,
          }}>
            {icon}
          </div>
        ) : <span />}

        {trend !== undefined && trend !== null && <TrendBadge value={trend} />}
      </div>

      {/* Value */}
      <div style={{
        fontSize:   28,
        fontWeight: 800,
        color:      '#101828',
        fontFamily: "'Outfit', 'Inter', sans-serif",
        lineHeight: 1.2,
      }}>
        {value}
      </div>

      {/* Label */}
      <div style={{ fontSize: 13, color: '#475467', marginTop: 3 }}>
        {label}
      </div>

      {/* Sub */}
      {sub && (
        <div style={{ fontSize: 12, color: '#98A2B3', marginTop: 4 }}>
          {sub}
        </div>
      )}
    </div>
  );
}
