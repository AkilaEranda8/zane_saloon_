const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/** One row per service line on a walk-in (multi-select). */
const WalkInQueueService = sequelize.define('WalkInQueueService', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  walk_in_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  service_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  sort_order: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  /** Price snapshot at check-in (LKR). */
  line_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true,
  },
}, {
  tableName: 'walk_in_queue_services',
  timestamps: true,
  indexes: [
    { fields: ['walk_in_id'] },
    { fields: ['service_id'] },
    { unique: true, fields: ['walk_in_id', 'service_id'] },
  ],
});

module.exports = WalkInQueueService;
