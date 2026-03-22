// ── Breakpoints ────────────────────────────────────────────────────
export const breakpoints = {
  mobile:  640,
  tablet:  1024,
  queries: {
    mobile:  '@media (max-width: 639px)',
    tablet:  '@media (min-width: 640px) and (max-width: 1023px)',
    desktop: '@media (min-width: 1024px)',
    narrow:  '@media (max-width: 1023px)',
  },
};

export const colors = {
  // Backgrounds
  bg:        "#F7F8FA",
  surface:   "#FFFFFF",
  surfaceAlt:"#F9FAFB",
  overlay:   "rgba(16,24,40,0.5)",

  // Borders
  border:    "#EAECF0",
  borderFoc: "#84ADFF",

  // Text
  text:      "#101828",
  textSub:   "#475467",
  textMut:   "#98A2B3",

  // Brand
  primary:   "#2563EB",
  primaryHov:"#1D4ED8",
  primaryL:  "#EFF6FF",
  primaryT:  "rgba(37,99,235,0.08)",

  // Semantic
  success:   "#059669", successL:"#D1FAE5",
  warn:      "#D97706", warnL:   "#FEF3C7",
  danger:    "#DC2626", dangerL: "#FEE2E2",
  purple:    "#7C3AED", purpleL: "#EDE9FE",
  cyan:      "#0891B2", cyanL:   "#CFFAFE",
  pink:      "#BE185D", pinkL:   "#FCE7F3",
};

export const shadows = {
  xs: "0 1px 2px rgba(16,24,40,.05)",
  sm: "0 1px 3px rgba(16,24,40,.10), 0 1px 2px rgba(16,24,40,.06)",
  md: "0 4px 8px -2px rgba(16,24,40,.10), 0 2px 4px -2px rgba(16,24,40,.06)",
  lg: "0 12px 16px -4px rgba(16,24,40,.08), 0 4px 6px -2px rgba(16,24,40,.03)",
  xl: "0 20px 24px -4px rgba(16,24,40,.08), 0 8px 8px -4px rgba(16,24,40,.03)",
};

export const radius = { sm:"6px", md:"10px", lg:"14px", xl:"20px", full:"9999px" };

export const spacing = { 1:4, 2:8, 3:12, 4:16, 5:20, 6:24, 8:32, 10:40, 12:48 };

export const fontSize = {
  xs:12, sm:13, base:14, md:15, lg:16, xl:18, "2xl":20, "3xl":24, "4xl":30,
};
