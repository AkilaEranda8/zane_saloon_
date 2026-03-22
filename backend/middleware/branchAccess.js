/**
 * branchAccess middleware
 *
 * - For manager/staff: sets req.userBranchId to their assigned branch,
 *   so controllers can auto-filter queries.
 * - For superadmin/admin: req.userBranchId is null (sees all branches).
 *
 * Must be used AFTER verifyToken.
 */
const branchAccess = (req, res, next) => {
  if (req.user) {
    const { role, branchId } = req.user;
    req.userBranchId = (role === 'manager' || role === 'staff') ? branchId : null;
  }
  next();
};

module.exports = { branchAccess };
