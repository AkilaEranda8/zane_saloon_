/**
 * branchAccess middleware
 *
 * - For manager/staff: sets req.userBranchIds (1–2 ids) and req.userBranchId (primary),
 *   so controllers can auto-filter queries.
 * - For superadmin/admin: req.userBranchId / req.userBranchIds are null (sees all branches).
 *
 * Must be used AFTER verifyToken.
 */
const { jwtBranchIds } = require('../utils/branchScope');

const branchAccess = (req, res, next) => {
  if (req.user) {
    const { role } = req.user;
    if (role === 'manager' || role === 'staff') {
      req.userBranchIds = jwtBranchIds(req.user);
      req.userBranchId = req.userBranchIds[0] ?? req.user.branchId ?? null;
    } else {
      req.userBranchIds = null;
      req.userBranchId = null;
    }
  }
  next();
};

module.exports = { branchAccess };
