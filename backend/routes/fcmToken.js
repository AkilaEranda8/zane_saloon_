'use strict';

const { Router } = require('express');
const { registerToken, removeToken } = require('../controllers/fcmTokenController');
const { verifyToken } = require('../middleware/auth');

const router = Router();

router.post('/',   verifyToken, registerToken);
router.delete('/', verifyToken, removeToken);

module.exports = router;
