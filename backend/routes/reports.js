const { Router } = require('express');
const ctrl = require('../controllers/reportController');
const { verifyToken } = require('../middleware/auth');
const { branchAccess } = require('../middleware/branchAccess');

const router = Router();
router.use(verifyToken, branchAccess);

router.get('/revenue',      ctrl.revenue);
router.get('/services',     ctrl.services);
router.get('/staff',        ctrl.staffReport);
router.get('/appointments', ctrl.appointmentStats);
router.get('/dashboard',    ctrl.dashboard);
router.get('/export',       ctrl.exportExcel);

module.exports = router;
