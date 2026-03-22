// Status variant → { bg, color }
const STATUS_MAP = {
  confirmed:  { bg: '#EFF6FF', color: '#1D4ED8' },
  completed:  { bg: '#D1FAE5', color: '#059669' },
  pending:    { bg: '#FEF3C7', color: '#D97706' },
  cancelled:  { bg: '#FEE2E2', color: '#DC2626' },
  active:     { bg: '#D1FAE5', color: '#059669' },
  inactive:   { bg: '#F2F4F7', color: '#64748B' },
  paid:       { bg: '#D1FAE5', color: '#059669' },
  present:    { bg: '#D1FAE5', color: '#059669' },
  absent:     { bg: '#FEE2E2', color: '#DC2626' },
  leave:      { bg: '#FEF3C7', color: '#D97706' },
  waiting:    { bg: '#FEF3C7', color: '#D97706' },
  serving:    { bg: '#EFF6FF', color: '#1D4ED8' },
  gold:       { bg: '#FEF3C7', color: '#D97706' },
  silver:     { bg: '#F1F5F9', color: '#64748B' },
  bronze:     { bg: '#FEF0E4', color: '#92400E' },
};

// Role variant → { bg, color }
const ROLE_MAP = {
  superadmin: { bg: '#EDE9FE', color: '#7C3AED' },
  admin:      { bg: '#EFF6FF', color: '#1D4ED8' },
  manager:    { bg: '#CFFAFE', color: '#0891B2' },
  staff:      { bg: '#FEF3C7', color: '#D97706' },
};

const SIZE_MAP = {
  sm: { padding: '2px 10px', fontSize: 12 },
  md: { padding: '4px 12px', fontSize: 12 },
};

function resolveStyle(key) {
  if (!key) return { bg: '#F2F4F7', color: '#64748B' };
  const k = String(key).toLowerCase();
  return STATUS_MAP[k] || ROLE_MAP[k] || { bg: '#F2F4F7', color: '#64748B' };
}

/**
 * Base Badge — pass variant (string key) and children (display text).
 * Auto-resolves color from STATUS_MAP and ROLE_MAP.
 */
export default function Badge({ variant, size = 'md', dot = false, children }) {
  const { bg, color } = resolveStyle(variant ?? children);
  const sz = SIZE_MAP[size] ?? SIZE_MAP.md;

  return (
    <span style={{
      display:     'inline-flex',
      alignItems:  'center',
      gap:         dot ? 5 : 0,
      background:  bg,
      color,
      borderRadius: 9999,
      padding:     sz.padding,
      fontSize:    sz.fontSize,
      fontWeight:  600,
      fontFamily:  "'Inter', sans-serif",
      lineHeight:  1.5,
      whiteSpace:  'nowrap',
    }}>
      {dot && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: color, flexShrink: 0, display: 'inline-block',
        }} />
      )}
      {children}
    </span>
  );
}

/** Convenience wrapper — renders status value as both variant and label. */
export function StatusBadge({ status, size, dot }) {
  if (!status) return null;
  const label = String(status).charAt(0).toUpperCase() + String(status).slice(1);
  return <Badge variant={status} size={size} dot={dot}>{label}</Badge>;
}

/** Convenience wrapper — renders role value as both variant and label. */
export function RoleBadge({ role, size, dot }) {
  if (!role) return null;
  const label = String(role).charAt(0).toUpperCase() + String(role).slice(1);
  return <Badge variant={role} size={size} dot={dot}>{label}</Badge>;
}
