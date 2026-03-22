const { Router } = require('express');
const ctrl = require('../controllers/inventoryController');
const { verifyToken, requireRole } = require('../middleware/auth');
const { branchAccess } = require('../middleware/branchAccess');

const router = Router();
router.use(verifyToken, branchAccess);

router.get('/low-stock',      ctrl.lowStock);
router.get('/',               ctrl.list);
router.post('/',              ctrl.create);
router.put('/:id',            ctrl.update);
router.delete('/:id',         requireRole('superadmin', 'admin', 'manager'), ctrl.remove);
router.patch('/:id/adjust',   ctrl.adjust);

module.exports = router;
