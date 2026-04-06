require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { sequelize } = require('../config/database');

const qi = sequelize.getQueryInterface();

async function addIfMissing(table, column, definition) {
  try {
    await qi.addColumn(table, column, definition);
    console.log(`  + ${table}.${column}`);
  } catch (e) {
    if (/duplicate column/i.test(e.message) || e.original?.code === 'ER_DUP_FIELDNAME') {
      // already exists — skip
    } else {
      console.warn(`  ! ${table}.${column}: ${e.message}`);
    }
  }
}

(async () => {
  try {
    await sequelize.authenticate();
    console.log('✓ DB connected');

    const { DataTypes } = require('sequelize');

    // ── notification_settings missing columns ────────────────────────────────
    await addIfMissing('notification_settings', 'appt_confirmed_sms',      { type: DataTypes.BOOLEAN, defaultValue: false, allowNull: false });
    await addIfMissing('notification_settings', 'payment_receipt_sms',     { type: DataTypes.BOOLEAN, defaultValue: true,  allowNull: false });
    await addIfMissing('notification_settings', 'loyalty_points_sms',      { type: DataTypes.BOOLEAN, defaultValue: false, allowNull: false });
    await addIfMissing('notification_settings', 'customer_registered_sms', { type: DataTypes.BOOLEAN, defaultValue: false, allowNull: false });
    await addIfMissing('notification_settings', 'customer_registered_email',{ type: DataTypes.BOOLEAN, defaultValue: false, allowNull: false });
    await addIfMissing('notification_settings', 'sms_sender_id',           { type: DataTypes.STRING(50), allowNull: true });
    await addIfMissing('notification_settings', 'sms_user_id',             { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'sms_api_key',             { type: DataTypes.TEXT, allowNull: true });
    await addIfMissing('notification_settings', 'twilio_account_sid',      { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'twilio_auth_token',       { type: DataTypes.TEXT, allowNull: true });
    await addIfMissing('notification_settings', 'twilio_whatsapp_from',    { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'smtp_host',               { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'smtp_port',               { type: DataTypes.INTEGER, allowNull: true });
    await addIfMissing('notification_settings', 'smtp_user',               { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'smtp_from',               { type: DataTypes.STRING, allowNull: true });
    await addIfMissing('notification_settings', 'smtp_pass',               { type: DataTypes.TEXT, allowNull: true });

    // ── appointments status ENUM — add in_service ────────────────────────────
    await sequelize.query(`ALTER TABLE appointments MODIFY COLUMN status ENUM('pending','confirmed','in_service','completed','cancelled') NOT NULL DEFAULT 'pending'`).catch(e => console.warn('  ! appointments.status ENUM:', e.message));

    // ── payments missing columns ──────────────────────────────────────────────
    await addIfMissing('payments', 'promo_discount', { type: DataTypes.DECIMAL(10, 2), defaultValue: 0, allowNull: true });

    // ── staff missing columns ────────────────────────────────────────────────
    await addIfMissing('staff', 'email', { type: DataTypes.STRING, allowNull: true });

    // ── users missing columns ────────────────────────────────────────────────
    await addIfMissing('users', 'staff_id', { type: DataTypes.INTEGER, allowNull: true });

    console.log('✓ Migration complete');
  } catch (err) {
    console.error('✗ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
})();
