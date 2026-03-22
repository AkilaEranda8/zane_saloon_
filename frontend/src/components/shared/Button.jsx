import React from 'react';
import { colors } from './theme';

export default function Button({
  children, onClick, type = 'button', variant = 'primary',
  size = 'md', disabled = false, style: extraStyle = {},
}) {
  const base = {
    display: 'inline-flex', alignItems: 'center', gap: 6,
    border: 'none', borderRadius: 8, cursor: disabled ? 'not-allowed' : 'pointer',
    fontWeight: 600, fontFamily: 'inherit', transition: 'opacity .15s',
    opacity: disabled ? 0.55 : 1,
  };

  const sizes = { sm: { padding: '5px 12px', fontSize: 13 }, md: { padding: '8px 18px', fontSize: 14 }, lg: { padding: '11px 24px', fontSize: 15 } };

  const variants = {
    primary:   { background: `linear-gradient(135deg, ${colors.primary}, ${colors.accent})`, color: '#fff' },
    secondary: { background: colors.bg, color: colors.dark, border: `1px solid ${colors.border}` },
    danger:    { background: colors.danger, color: '#fff' },
    success:   { background: colors.success, color: '#fff' },
    ghost:     { background: 'transparent', color: colors.muted, border: `1px solid ${colors.border}` },
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      style={{ ...base, ...sizes[size], ...variants[variant], ...extraStyle }}
    >
      {children}
    </button>
  );
}
