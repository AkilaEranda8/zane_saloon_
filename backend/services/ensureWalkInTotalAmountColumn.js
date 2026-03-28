const { sequelize } = require('../config/database');

/** Adds walk_in_queue.total_amount when missing (multi-service walk-in totals). */
async function ensureWalkInTotalAmountColumn() {
  try {
    const qi = sequelize.getQueryInterface();
    const table = await qi.describeTable('walk_in_queue');
    if (table.total_amount) return;
    await sequelize.query(
      'ALTER TABLE walk_in_queue ADD COLUMN total_amount DECIMAL(10,2) NULL',
    );
    console.log('✓ Added walk_in_queue.total_amount column');
  } catch (e) {
    const msg = e && e.message ? String(e.message) : '';
    if (/doesn't exist|no such table|Unknown table/i.test(msg)) return;
    throw e;
  }
}

module.exports = { ensureWalkInTotalAmountColumn };
