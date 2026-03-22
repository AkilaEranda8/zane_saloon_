import { useState, useEffect } from 'react';

// Breakpoints must match global.css / design-system
const BP = { mobile: 640, tablet: 1024 };

function getBreakpoint(w) {
  if (w < BP.mobile)  return 'mobile';
  if (w < BP.tablet)  return 'tablet';
  return 'desktop';
}

/**
 * Returns responsive breakpoint flags.
 *
 * const { isMobile, isTablet, isDesktop, breakpoint } = useBreakpoint();
 */
export function useBreakpoint() {
  const [bp, setBp] = useState(() => getBreakpoint(window.innerWidth));

  useEffect(() => {
    const update = () => setBp(getBreakpoint(window.innerWidth));
    window.addEventListener('resize', update, { passive: true });
    return () => window.removeEventListener('resize', update);
  }, []);

  return {
    breakpoint: bp,
    isMobile:   bp === 'mobile',
    isTablet:   bp === 'tablet',
    isDesktop:  bp === 'desktop',
    isNarrow:   bp === 'mobile' || bp === 'tablet',
  };
}

export default useBreakpoint;
