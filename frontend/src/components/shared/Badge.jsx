import React from 'react';
import { STATUS_COLORS } from './theme';

export default function Badge({ label, type }) {
  const scheme = STATUS_COLORS[type] || STATUS_COLORS[label?.toLowerCase()] || { bg: '#f1f5f9', text: '#334155', dot: '#94a3b8' };

  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 10px', borderRadius: 20,
      background: scheme.bg, color: scheme.text,
      fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
    }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: scheme.dot, flexShrink: 0 }} />
      {label}
    </span>
  );
}
