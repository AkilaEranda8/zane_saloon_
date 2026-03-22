import { useState } from 'react';

const Spinner = () => (
  <svg
    width="15" height="15" viewBox="0 0 15 15" fill="none"
    style={{ animation: 'btn-spin 0.65s linear infinite', flexShrink: 0 }}
  >
    <style>{`@keyframes btn-spin { to { transform: rotate(360deg); } }`}</style>
    <circle cx="7.5" cy="7.5" r="5.5" stroke="currentColor" strokeOpacity="0.3" strokeWidth="2.5" />
    <path d="M13 7.5a5.5 5.5 0 0 0-5.5-5.5" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
  </svg>
);

const VARIANTS = {
  primary:   { bg: '#2563EB',     hoverBg: '#1D4ED8',  color: '#fff',    border: 'none' },
  secondary: { bg: '#F2F4F7',     hoverBg: '#E4E7EC',  color: '#344054', border: 'none' },
  danger:    { bg: '#DC2626',     hoverBg: '#B91C1C',  color: '#fff',    border: 'none' },
  ghost:     { bg: 'transparent', hoverBg: '#F2F4F7',  color: '#475467', border: 'none' },
  outline:   { bg: '#fff',        hoverBg: '#F9FAFB',  color: '#344054', border: '1.5px solid #D0D5DD' },
};

const SIZES = {
  sm: { padding: '6px 12px',  fontSize: 13, borderRadius: 8  },
  md: { padding: '9px 16px',  fontSize: 14, borderRadius: 10 },
  lg: { padding: '12px 20px', fontSize: 15, borderRadius: 12 },
};

export default function Button({
  variant = 'primary',
  size    = 'md',
  loading = false,
  icon,
  iconRight,
  fullWidth = false,
  disabled  = false,
  onClick,
  children,
  type = 'button',
  style: extraStyle,
  ...rest
}) {
  const [hovered, setHovered] = useState(false);
  const v = VARIANTS[variant] ?? VARIANTS.primary;
  const s = SIZES[size]       ?? SIZES.md;
  const isDisabled = disabled || loading;

  const style = {
    display:        'inline-flex',
    alignItems:     'center',
    justifyContent: 'center',
    gap:            7,
    padding:        s.padding,
    fontSize:       s.fontSize,
    fontFamily:     "'Inter', sans-serif",
    fontWeight:     600,
    borderRadius:   s.borderRadius,
    background:     hovered && !isDisabled ? v.hoverBg : v.bg,
    color:          v.color,
    border:         v.border,
    outline:        'none',
    cursor:         isDisabled ? 'not-allowed' : loading ? 'wait' : 'pointer',
    opacity:        loading ? 0.75 : isDisabled ? 0.5 : 1,
    width:          fullWidth ? '100%' : undefined,
    lineHeight:     1.4,
    userSelect:     'none',
    transition:     'background 0.15s',
    boxSizing:      'border-box',
    textDecoration: 'none',
  };

  return (
    <button
      type={type}
      style={extraStyle ? { ...style, ...extraStyle } : style}
      disabled={isDisabled}
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      {...rest}
    >
      {loading
        ? <Spinner />
        : icon
          ? <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>{icon}</span>
          : null
      }
      {children !== undefined && children !== null && (
        <span>{children}</span>
      )}
      {!loading && iconRight && (
        <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>{iconRight}</span>
      )}
    </button>
  );
}
