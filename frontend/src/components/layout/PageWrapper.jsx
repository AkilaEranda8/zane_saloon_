import { useBreakpoint } from '../../hooks/useBreakpoint';

export default function PageWrapper({ title, subtitle, actions, children }) {
  const { isMobile, isTablet } = useBreakpoint();
  const pad = isMobile ? 12 : isTablet ? 16 : 24;
  const gap = isMobile ? 16 : 24;

  return (
    <div
      className="page-enter"
      style={{
        display:       'flex',
        flexDirection: 'column',
        gap,
        padding:       pad,
        minHeight:     '100%',
        boxSizing:     'border-box',
        fontFamily:    "'Inter', sans-serif",
      }}
    >
      {/* Page header */}
      {(title || actions) && (
        <div style={{
          display:        'flex',
          alignItems:     'flex-start',
          justifyContent: 'space-between',
          gap:            16,
          flexWrap:       'wrap',
        }}>
          {/* Title block */}
          <div>
            {title && (
              <h1 style={{
                margin:     0,
                fontSize:   24,
                fontWeight: 800,
                color:      '#101828',
                fontFamily: "'Outfit', 'Inter', sans-serif",
                lineHeight: 1.25,
              }}>
                {title}
              </h1>
            )}
            {subtitle && (
              <p style={{
                margin:     '4px 0 0',
                fontSize:   14,
                color:      '#475467',
                lineHeight: 1.5,
              }}>
                {subtitle}
              </p>
            )}
          </div>

          {/* Actions slot */}
          {actions && (
            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', flexShrink: 0 }}>
              {actions}
            </div>
          )}
        </div>
      )}

      {children}
    </div>
  );
}
