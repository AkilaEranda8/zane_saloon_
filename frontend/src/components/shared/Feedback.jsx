import React from 'react';
import { colors } from './theme';

export function LoadingSpinner({ size = 40 }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '3rem' }}>
      <div style={{
        width: size, height: size, borderRadius: '50%',
        border: `3px solid ${colors.border}`,
        borderTopColor: colors.primary,
        animation: 'spin 0.7s linear infinite',
      }} />
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

export function ErrorMessage({ message }) {
  if (!message) return null;
  return (
    <div style={{
      padding: '12px 16px', borderRadius: 10,
      background: '#fee2e2', color: '#991b1b',
      fontSize: 14, fontWeight: 500,
    }}>
      ⚠ {message}
    </div>
  );
}
