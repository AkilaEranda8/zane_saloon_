const { sequelize } = require('../config/database');

/** Adds users.staff_id when missing (older DBs). Safe to call on every startup. */
async function ensureUsersStaffIdColumn() {
  try {
    const qi = sequelize.getQueryInterface();
    const table = await qi.describeTable('users');
    if (table.staff_id) return;
    await sequelize.query('ALTER TABLE users ADD COLUMN staff_id INT NULL');
    console.log('✓ Added users.staff_id column');
  } catch (e) {
    const msg = e && e.message ? String(e.message) : '';
    if (/doesn't exist|no such table|Unknown table/i.test(msg)) return;
    throw e;
  }
}

module.exports = { ensureUsersStaffIdColumn };
