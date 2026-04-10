const { Router } = require('express');
const { verifyToken, PERMISSIONS } = require('../middleware/auth');

const router = Router();

const API_MODULES = [
  { basePath: '/api/health', auth: 'public', description: 'Health check' },
  { basePath: '/api/public', auth: 'public', description: 'Public booking and portal APIs' },
  { basePath: '/api/auth', auth: 'mixed', description: 'Authentication and profile APIs' },
  { basePath: '/api/system', auth: 'public/mixed', description: 'System metadata and permissions' },
  { basePath: '/api/branches', auth: 'jwt', description: 'Branch management' },
  { basePath: '/api/services', auth: 'jwt', description: 'Service catalog management' },
  { basePath: '/api/staff', auth: 'jwt', description: 'Staff profiles and assignment' },
  { basePath: '/api/appointments', auth: 'jwt', description: 'Appointments and calendar' },
  { basePath: '/api/customers', auth: 'jwt', description: 'Customer records' },
  { basePath: '/api/payments', auth: 'jwt', description: 'Payment and split settlements' },
  { basePath: '/api/inventory', auth: 'jwt', description: 'Stock and inventory operations' },
  { basePath: '/api/attendance', auth: 'jwt', description: 'Attendance tracking' },
  { basePath: '/api/reminders', auth: 'jwt', description: 'Reminder scheduling' },
  { basePath: '/api/reports', auth: 'jwt', description: 'Business reports and analytics' },
  { basePath: '/api/users', auth: 'jwt', description: 'User administration' },
  { basePath: '/api/walkin', auth: 'jwt', description: 'Walk-in customer management' },
  { basePath: '/api/expenses', auth: 'jwt', description: 'Expense management' },
  { basePath: '/api/notifications', auth: 'jwt', description: 'Notifications and logs' },
  { basePath: '/api/reviews', auth: 'jwt', description: 'Customer reviews' },
  { basePath: '/api/packages', auth: 'jwt', description: 'Packages and redemptions' },
  { basePath: '/api/discounts', auth: 'jwt', description: 'Discounts and offers' },
  { basePath: '/api/fcm-token', auth: 'jwt', description: 'FCM token registration' },
];

router.get('/', (_req, res) => {
  res.json({
    service: 'Zane Salon API',
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    now: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    modules: API_MODULES,
  });
});

router.get('/status', (_req, res) => {
  const memory = process.memoryUsage();
  res.json({
    status: 'ok',
    now: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    memory: {
      rss: memory.rss,
      heapTotal: memory.heapTotal,
      heapUsed: memory.heapUsed,
      external: memory.external,
    },
  });
});

router.get('/me-permissions', verifyToken, (req, res) => {
  const role = req.user?.role;
  res.json({
    role,
    permissions: role && PERMISSIONS[role] ? PERMISSIONS[role] : {},
    allRoles: PERMISSIONS,
  });
});

module.exports = router;