const { Router } = require('express');
const ctrl = require('../controllers/serviceController');
const { verifyToken, requireRole } = require('../middleware/auth');

const router = Router();
router.use(verifyToken);

router.get('/categories', ctrl.categories);
router.get('/',       ctrl.list);
router.get('/:id',    ctrl.getOne);
router.post('/',      requireRole('superadmin', 'admin'), ctrl.create);
router.put('/:id',    requireRole('superadmin', 'admin'), ctrl.update);
router.delete('/:id', requireRole('superadmin', 'admin'), ctrl.remove);
router.put('/categories/rename', requireRole('superadmin', 'admin'), ctrl.renameCategory);
router.post('/categories/delete', requireRole('superadmin', 'admin'), ctrl.deleteCategory);

module.exports = router;
