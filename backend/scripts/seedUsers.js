require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const bcrypt = require('bcryptjs');
const { sequelize } = require('../config/database');
const { Branch, User } = require('../models');

const SALT_ROUNDS = 10;

async function seed() {
  await sequelize.authenticate();
  console.log('✓ DB connected');

  // ── Create demo branches first ─────────────────────────────────────────────
  const [branch1] = await Branch.findOrCreate({
    where: { name: 'Main Branch' },
    defaults: { address: '123 Main Street', phone: '0300-1234567', status: 'active', color: '#6366f1' },
  });
  const [branch2] = await Branch.findOrCreate({
    where: { name: 'Downtown Branch' },
    defaults: { address: '456 Downtown Ave', phone: '0300-7654321', status: 'active', color: '#8b5cf6' },
  });

  // ── Demo users ─────────────────────────────────────────────────────────────
  const users = [
    {
      username:  'superadmin',
      password:  'admin123',
      name:      'Super Admin',
      role:      'superadmin',
      branch_id: null,
      color:     '#ef4444',
    },
    {
      username:  'admin',
      password:  'admin123',
      name:      'Admin User',
      role:      'admin',
      branch_id: null,
      color:     '#f97316',
    },
    {
      username:  'manager1',
      password:  'manager123',
      name:      'Manager (Main)',
      role:      'manager',
      branch_id: branch1.id,
      color:     '#3b82f6',
    },
    {
      username:  'manager2',
      password:  'manager123',
      name:      'Manager (Downtown)',
      role:      'manager',
      branch_id: branch2.id,
      color:     '#06b6d4',
    },
    {
      username:  'staff1',
      password:  'staff123',
      name:      'Staff One',
      role:      'staff',
      branch_id: branch1.id,
      color:     '#10b981',
    },
    {
      username:  'staff2',
      password:  'staff123',
      name:      'Staff Two',
      role:      'staff',
      branch_id: branch2.id,
      color:     '#84cc16',
    },
  ];

  for (const u of users) {
    const hashed = await bcrypt.hash(u.password, SALT_ROUNDS);
    const [user, created] = await User.findOrCreate({
      where: { username: u.username },
      defaults: {
        password:  hashed,
        name:      u.name,
        role:      u.role,
        branch_id: u.branch_id,
        color:     u.color,
        is_active: true,
      },
    });
    console.log(`${created ? '✓ Created' : '~ Exists '} user: ${user.username} (${user.role})`);
  }

  await sequelize.close();
  console.log('\n✓ Seed complete');
}

seed().catch((err) => {
  console.error('✗ Seed failed:', err.message);
  process.exit(1);
});
