const { Op } = require('sequelize');
const { sequelize } = require('../config/database');
const { WalkIn, WalkInQueueService, Service } = require('../models');

const EXTRA_PREFIX_REGEX = /^\s*Additional\s+services:\s*/i;

function parseAdditionalServiceNamesFromNote(note = '') {
  const line = String(note).split('\n').find((l) => EXTRA_PREFIX_REGEX.test(l.trim()));
  if (!line) return [];
  return line
    .replace(EXTRA_PREFIX_REGEX, '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

async function ensureWalkInQueueServicesTable() {
  await sequelize.query(`
    CREATE TABLE IF NOT EXISTS walk_in_queue_services (
      id INT AUTO_INCREMENT PRIMARY KEY,
      walk_in_id INT NOT NULL,
      service_id INT NOT NULL,
      sort_order INT NOT NULL DEFAULT 0,
      line_price DECIMAL(10,2) NULL,
      createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_walkin_service (walk_in_id, service_id),
      KEY idx_walk_in_id (walk_in_id),
      KEY idx_service_id (service_id),
      CONSTRAINT fk_wiqs_walk_in FOREIGN KEY (walk_in_id) REFERENCES walk_in_queue(id) ON DELETE CASCADE,
      CONSTRAINT fk_wiqs_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
  `);
}

/**
 * Backfill junction rows for existing walk-ins that only had note + primary service_id.
 */
async function backfillWalkInQueueServices() {
  const [mappedRows] = await sequelize.query(
    'SELECT DISTINCT walk_in_id FROM walk_in_queue_services',
  );
  const have = new Set(mappedRows.map((r) => Number(r.walk_in_id)).filter(Boolean));

  const walkIns = await WalkIn.findAll({
    attributes: ['id', 'service_id', 'note', 'total_amount'],
    raw: true,
  });
  const inserts = [];

  for (const w of walkIns) {
    const wid = Number(w.id);
    if (have.has(wid)) continue;

    const primaryId = Number(w.service_id || 0);
    const names = parseAdditionalServiceNamesFromNote(w.note || '');
    const extraServices = names.length
      ? await Service.findAll({
        where: { name: { [Op.in]: names } },
        attributes: ['id', 'name', 'price'],
        raw: true,
      })
      : [];
    const nameToRow = new Map(extraServices.map((s) => [String(s.name), s]));

    const orderedIds = [];
    if (primaryId) orderedIds.push(primaryId);
    for (const n of names) {
      const row = nameToRow.get(n);
      const sid = row ? Number(row.id) : 0;
      if (sid && !orderedIds.includes(sid)) orderedIds.push(sid);
    }
    if (!orderedIds.length) continue;

    const svcRows = await Service.findAll({
      where: { id: orderedIds },
      attributes: ['id', 'price'],
      raw: true,
    });
    const priceById = Object.fromEntries(svcRows.map((s) => [Number(s.id), Number(s.price || 0)]));

    orderedIds.forEach((sid, idx) => {
      inserts.push({
        walk_in_id: wid,
        service_id: sid,
        sort_order: idx,
        line_price: priceById[sid] ?? null,
      });
    });
  }

  if (!inserts.length) return 0;
  await WalkInQueueService.bulkCreate(inserts, { ignoreDuplicates: true });
  return inserts.length;
}

async function runWalkInQueueServicesMigration() {
  await ensureWalkInQueueServicesTable();
  const n = await backfillWalkInQueueServices();
  console.log(`✓ walk_in_queue_services table ready (backfilled rows: ${n})`);
}

module.exports = { runWalkInQueueServicesMigration, ensureWalkInQueueServicesTable };
