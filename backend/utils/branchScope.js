/**
 * Derive branch id list from JWT payload (camelCase branchId) or DB-shaped user.
 */
function jwtBranchIds(user) {
  if (!user) return [];
  const raw = user.branchId ?? user.branch_id;
  if (raw == null || raw === '') return [];
  const n = Number(raw);
  return Number.isFinite(n) ? [n] : [];
}

module.exports = { jwtBranchIds };
