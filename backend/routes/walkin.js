const { Router } = require('express');
const ctrl = require('../controllers/walkinController');
const { verifyToken } = require('../middleware/auth');

const router = Router();

// ── Public GET endpoints (no auth) — used by both management page and display screen
router.get('/',              ctrl.list);
router.get('/stats',         ctrl.stats);

// ── Write endpoints require authentication ──────────────────────────────────
router.use(verifyToken);

router.post('/checkin',      ctrl.checkin);
router.patch('/:id/status',  ctrl.updateStatus);
router.patch('/:id/assign',  ctrl.assign);
router.delete('/:id',        ctrl.remove);

module.exports = router;
