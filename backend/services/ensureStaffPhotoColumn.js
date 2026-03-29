const { sequelize } = require('../config/database');

/** Adds staff.photo_url when missing. Safe on every startup. */
async function ensureStaffPhotoColumn() {
  try {
    const qi = sequelize.getQueryInterface();
    const table = await qi.describeTable('staff');
    if (table.photo_url) return;
    await sequelize.query('ALTER TABLE staff ADD COLUMN photo_url VARCHAR(255) NULL');
    console.log('✓ Added staff.photo_url column');
  } catch (e) {
    const msg = e && e.message ? String(e.message) : '';
    if (/doesn't exist|no such table|Unknown table/i.test(msg)) return;
    throw e;
  }
}

module.exports = { ensureStaffPhotoColumn };
