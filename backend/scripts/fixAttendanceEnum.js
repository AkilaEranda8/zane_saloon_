const { sequelize } = require('../config/database');

(async () => {
  try {
    // Add 'late' to the ENUM
    await sequelize.query(
      "ALTER TABLE attendance MODIFY COLUMN status ENUM('present','absent','leave','late') DEFAULT 'present'"
    );
    console.log('Step 1: ENUM updated with late');

    // Sync all models
    await sequelize.sync({ alter: true });
    console.log('Step 2: Models synced');

    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
