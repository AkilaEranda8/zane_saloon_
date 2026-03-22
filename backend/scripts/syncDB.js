require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { sequelize } = require('../config/database');
// Import models so Sequelize registers them before sync
require('../models');

(async () => {
  try {
    await sequelize.authenticate();
    console.log('✓ Database connection OK');

    await sequelize.sync({ force: false, alter: true });
    console.log('✓ All tables synced (alter:true)');
  } catch (err) {
    console.error('✗ Sync failed:', err.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
})();
