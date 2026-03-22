'use strict';
const router       = require('express').Router();
const ctrl         = require('../controllers/reviewController');
const { verifyToken } = require('../middleware/auth');
const { branchAccess } = require('../middleware/branchAccess');

// ── Public (no auth required) ─────────────────────────────────────────────────
router.get('/form/:token',    ctrl.getForm);
router.post('/submit/:token', ctrl.submitReview);

// ── Protected ─────────────────────────────────────────────────────────────────
router.use(verifyToken, branchAccess);
router.get('/',      ctrl.list);
router.get('/stats', ctrl.stats);
router.patch('/:id/approve', ctrl.approve);
router.delete('/:id',        ctrl.remove);

module.exports = router;
