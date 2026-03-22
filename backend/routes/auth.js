const { Router } = require('express');
const { register, login, logout, getMe } = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');

const router = Router();

// POST /api/auth/register
router.post('/register', register);

// POST /api/auth/login
router.post('/login', login);

// POST /api/auth/logout
router.post('/logout', logout);

// GET /api/auth/me  (protected)
router.get('/me', verifyToken, getMe);

module.exports = router;
