const { sequelize } = require('../config/database');

/** Adds staff.email when missing (deploys before manual migration). Safe on every startup. */
async function ensureStaffEmailColumn() {
  try {
    const qi = sequelize.getQueryInterface();
    const table = await qi.describeTable('staff');
    if (table.email) return;
    await sequelize.query('ALTER TABLE staff ADD COLUMN email VARCHAR(191) NULL');
    console.log('✓ Added staff.email column');
  } catch (e) {
    const msg = e && e.message ? String(e.message) : '';
    if (/doesn't exist|no such table|Unknown table/i.test(msg)) return;
    throw e;
  }
}

module.exports = { ensureStaffEmailColumn };
