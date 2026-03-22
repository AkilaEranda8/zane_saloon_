const { Router } = require('express');
const ctrl = require('../controllers/attendanceController');
const { verifyToken } = require('../middleware/auth');
const { branchAccess } = require('../middleware/branchAccess');

const router = Router();
router.use(verifyToken, branchAccess);

router.get('/summary', ctrl.summary);
router.get('/',        ctrl.list);
router.post('/',       ctrl.upsert);
router.put('/:id',     ctrl.update);

module.exports = router;
