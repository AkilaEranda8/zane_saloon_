import React from 'react';
import { colors } from './theme';

export default function StatCard({ label, value, icon, color = colors.primary, sub }) {
  return (
    <div style={{
      background: colors.white,
      borderRadius: 14, padding: '1.25rem 1.5rem',
      boxShadow: '0 1px 8px rgba(0,0,0,0.06)',
      display: 'flex', alignItems: 'center', gap: 16,
    }}>
      {icon && (
        <div style={{
          width: 48, height: 48, borderRadius: 12,
          background: color + '18', color,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 22, flexShrink: 0,
        }}>
          {icon}
        </div>
      )}
      <div>
        <div style={{ fontSize: 13, color: colors.muted, fontWeight: 500 }}>{label}</div>
        <div style={{ fontSize: 26, fontWeight: 800, color: colors.dark, lineHeight: 1.2 }}>{value ?? '—'}</div>
        {sub && <div style={{ fontSize: 12, color: colors.muted, marginTop: 2 }}>{sub}</div>}
      </div>
    </div>
  );
}
