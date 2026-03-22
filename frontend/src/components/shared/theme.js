// Design tokens — import this in any component for consistent styling
export const colors = {
  primary:     '#3b82f6',
  primaryDark: '#2563eb',
  accent:      '#8b5cf6',
  success:     '#10b981',
  warning:     '#f59e0b',
  danger:      '#ef4444',
  info:        '#06b6d4',
  dark:        '#1e293b',
  muted:       '#64748b',
  border:      '#e2e8f0',
  bg:          '#f8fafc',
  white:       '#ffffff',
  card:        '#ffffff',
};

export const STATUS_COLORS = {
  pending:   { bg: '#fef9c3', text: '#92400e', dot: '#f59e0b' },
  confirmed: { bg: '#dbeafe', text: '#1e40af', dot: '#3b82f6' },
  completed: { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  cancelled: { bg: '#fee2e2', text: '#991b1b', dot: '#ef4444' },
  paid:      { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  active:    { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  inactive:  { bg: '#f1f5f9', text: '#64748b', dot: '#94a3b8' },
  present:   { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  absent:    { bg: '#fee2e2', text: '#991b1b', dot: '#ef4444' },
  leave:     { bg: '#fef9c3', text: '#92400e', dot: '#f59e0b' },
  high:      { bg: '#fee2e2', text: '#991b1b', dot: '#ef4444' },
  medium:    { bg: '#fef9c3', text: '#92400e', dot: '#f59e0b' },
  low:       { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  sent:      { bg: '#d1fae5', text: '#065f46', dot: '#10b981' },
  failed:    { bg: '#fee2e2', text: '#991b1b', dot: '#ef4444' },
  email:     { bg: '#dbeafe', text: '#1e40af', dot: '#3b82f6' },
  whatsapp:  { bg: '#dcfce7', text: '#166534', dot: '#22c55e' },
};

export const ROLE_COLORS = {
  superadmin: { bg: '#fce7f3', text: '#9d174d' },
  admin:      { bg: '#ede9fe', text: '#5b21b6' },
  manager:    { bg: '#dbeafe', text: '#1e40af' },
  staff:      { bg: '#d1fae5', text: '#065f46' },
};
