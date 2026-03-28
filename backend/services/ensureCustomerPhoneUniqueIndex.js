const { sequelize } = require('../config/database');

/**
 * Replaces unique(phone, branch_id) with unique(phone) so one number = one customer system-wide.
 * Skips if duplicate non-empty phones still exist (manual cleanup required).
 */
async function ensureCustomerPhoneUniqueIndex() {
  try {
    const [dups] = await sequelize.query(`
      SELECT phone FROM customers
      WHERE phone IS NOT NULL AND TRIM(phone) <> ''
      GROUP BY phone
      HAVING COUNT(*) > 1
      LIMIT 1
    `);

    if (dups && dups.length > 0) {
      console.warn(
        '⚠  customers: duplicate phone values exist; resolve duplicates before enforcing global phone uniqueness.'
      );
      return;
    }

    const [oldIdx] = await sequelize.query(`
      SELECT INDEX_NAME FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 'customers'
      AND INDEX_NAME = 'customers_phone_branch_unique'
      LIMIT 1
    `);

    if (oldIdx && oldIdx.length > 0) {
      await sequelize.query('DROP INDEX `customers_phone_branch_unique` ON `customers`');
      console.log('✓ Dropped customers_phone_branch_unique index');
    }

    const [newIdx] = await sequelize.query(`
      SELECT INDEX_NAME FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 'customers'
      AND INDEX_NAME = 'customers_phone_unique'
      LIMIT 1
    `);

    if (!newIdx || newIdx.length === 0) {
      await sequelize.query(
        'CREATE UNIQUE INDEX `customers_phone_unique` ON `customers` (`phone`)'
      );
      console.log('✓ Created customers_phone_unique index');
    }
  } catch (e) {
    const msg = e && e.message ? String(e.message) : '';
    if (/doesn't exist|no such table|Unknown table/i.test(msg)) return;
    console.warn('⚠  ensureCustomerPhoneUniqueIndex:', msg);
  }
}

module.exports = { ensureCustomerPhoneUniqueIndex };
