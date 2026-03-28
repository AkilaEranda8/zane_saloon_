const { Op } = require('sequelize');
const { sequelize } = require('../config/database');
const { WalkIn, Service, Staff, Branch, WalkInQueueService } = require('../models');
const { emitQueueUpdate } = require('../socket');
const { sendSMS } = require('../services/notificationService');

// Helper: today as YYYY-MM-DD
const today = () => new Date().toISOString().slice(0, 10);

/** Ordered unique positive integer ids. */
function normalizeServiceIdList(raw) {
  if (!Array.isArray(raw) || raw.length === 0) return [];
  const out = [];
  const seen = new Set();
  for (const x of raw) {
    const n = Number(x);
    if (!Number.isNaN(n) && n > 0 && !seen.has(n)) {
      seen.add(n);
      out.push(n);
    }
  }
  return out;
}

/**
 * Loads services for ordered ids; returns { primaryId, totalAmount, durationSum }.
 * @param {import('sequelize').Transaction} [transaction]
 */
async function totalsFromServiceIds(orderedIds, transaction) {
  if (!orderedIds.length) {
    return { primaryId: null, totalAmount: 0, durationSum: 30 };
  }
  const services = await Service.findAll({
    where: { id: orderedIds },
    transaction,
  });
  if (services.length !== orderedIds.length) {
    throw Object.assign(new Error('One or more services not found.'), { status: 404 });
  }
  const byId = Object.fromEntries(services.map((s) => [s.id, s]));
  let totalAmount = 0;
  let durationSum = 0;
  for (const id of orderedIds) {
    const s = byId[id];
    totalAmount += Number(s.price || 0);
    durationSum += Number(s.duration_minutes || 30);
  }
  return { primaryId: orderedIds[0], totalAmount, durationSum };
}

async function replaceWalkInQueueServices(walkInId, orderedIds, transaction) {
  await WalkInQueueService.destroy({ where: { walk_in_id: walkInId }, transaction });
  if (!orderedIds.length) return;
  const services = await Service.findAll({ where: { id: orderedIds }, transaction });
  if (services.length !== orderedIds.length) {
    throw Object.assign(new Error('One or more services not found.'), { status: 404 });
  }
  const byId = Object.fromEntries(services.map((s) => [s.id, s]));
  const rows = orderedIds.map((sid, idx) => ({
    walk_in_id: walkInId,
    service_id: sid,
    sort_order: idx,
    line_price: Number(byId[sid]?.price || 0),
  }));
  await WalkInQueueService.bulkCreate(rows, { transaction });
}

// Helper: generate next token for a branch+date atomically inside a transaction
async function generateToken(branchId, date, transaction) {
  const count = await WalkIn.count({
    where: { branch_id: branchId, check_in_date: date },
    transaction,
    lock: transaction.LOCK.UPDATE,
  });
  const num = count + 1;
  return 'T' + String(num).padStart(3, '0');
}

// Include options reused across queries (primary service + joined walk-in service lines)
const fullWalkInInclude = [
  { model: Service, as: 'service', attributes: ['id', 'name', 'duration_minutes', 'price'] },
  { model: Staff, as: 'staff', attributes: ['id', 'name'] },
  {
    model: WalkInQueueService,
    as: 'walkInServices',
    attributes: ['id', 'service_id', 'sort_order', 'line_price'],
    separate: true,
    order: [['sort_order', 'ASC']],
    include: [{ model: Service, as: 'service', attributes: ['id', 'name', 'duration_minutes', 'price'] }],
  },
];

// ── GET /api/walkin ───────────────────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { branchId, date, status } = req.query;
    if (!branchId) return res.status(400).json({ message: 'branchId is required.' });
    if (req.userBranchId && Number(branchId) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. You can only view your own branch queue.' });
    }
    const where = {
      branch_id: branchId,
      check_in_date: date || today(),
    };
    if (status) where.status = status;

    const queue = await WalkIn.findAll({
      where,
      include: fullWalkInInclude,
      // Newest check-ins first; list index #1 = latest (matches staff app display).
      order: [['createdAt', 'DESC']],
    });

    res.json(queue);
  } catch (err) {
    console.error('walkin.list error:', err);
    res.status(500).json({ message: 'Failed to fetch walk-in queue.' });
  }
};

// ── GET /api/walkin/stats ─────────────────────────────────────────────────────
exports.stats = async (req, res) => {
  try {
    const { branchId, date } = req.query;
    if (!branchId) return res.status(400).json({ message: 'branchId is required.' });
    if (req.userBranchId && Number(branchId) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. You can only view your own branch queue.' });
    }
    const where = {
      branch_id: branchId,
      check_in_date: date || today(),
    };

    const all = await WalkIn.findAll({ where, attributes: ['status'] });

    const counts = { waiting: 0, serving: 0, completed: 0, cancelled: 0, total: all.length };
    all.forEach((r) => { counts[r.status]++; });

    res.json(counts);
  } catch (err) {
    console.error('walkin.stats error:', err);
    res.status(500).json({ message: 'Failed to fetch walk-in stats.' });
  }
};

// ── POST /api/walkin/checkin ──────────────────────────────────────────────────
exports.checkin = async (req, res) => {
  try {
    const { customerName, phone, branchId, serviceId, note, staffId } = req.body;
    // camelCase (web/mobile) or snake_case (some clients)
    const serviceIds = req.body.serviceIds ?? req.body.service_ids;

    if (!customerName || !branchId) {
      return res.status(400).json({ message: 'customerName and branchId are required.' });
    }
    if (!serviceId && !(Array.isArray(serviceIds) && serviceIds.length > 0)) {
      return res.status(400).json({ message: 'serviceId or serviceIds is required.' });
    }
    if (req.userBranchId && Number(branchId) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. You can only check in for your own branch.' });
    }

    const dateStr = today();

    const result = await sequelize.transaction(async (t) => {
      const token = await generateToken(branchId, dateStr, t);

      const orderedIds = normalizeServiceIdList(serviceIds);
      let primarySid;
      let totalAmount = 0;
      let durationSum = 30;

      if (orderedIds.length > 0) {
        const agg = await totalsFromServiceIds(orderedIds, t);
        primarySid = agg.primaryId;
        totalAmount = agg.totalAmount;
        durationSum = agg.durationSum;
      } else {
        primarySid = Number(serviceId);
        const service = await Service.findByPk(primarySid, { transaction: t });
        if (!service) throw Object.assign(new Error('Service not found.'), { status: 404 });
        totalAmount = Number(service.price || 0);
        durationSum = Number(service.duration_minutes || 30);
      }

      const waitingCount = await WalkIn.count({
        where: { branch_id: branchId, check_in_date: dateStr, status: 'waiting' },
        transaction: t,
      });
      const estimatedWait = waitingCount * durationSum;

      const entry = await WalkIn.create({
        token,
        customer_name: customerName,
        phone: phone || null,
        branch_id: branchId,
        service_id: primarySid,
        staff_id: staffId ? Number(staffId) : null,
        status: 'waiting',
        check_in_time: new Date().toTimeString().slice(0, 8),
        check_in_date: dateStr,
        estimated_wait: estimatedWait,
        note: note || null,
        total_amount: totalAmount,
      }, { transaction: t });

      const idsToPersist = orderedIds.length > 0 ? orderedIds : [primarySid];
      await replaceWalkInQueueServices(entry.id, idsToPersist, t);

      return WalkIn.findByPk(entry.id, { include: fullWalkInInclude, transaction: t });
    });

    const full = result;

    // Send token SMS to customer (non-blocking)
    const customerPhone = full?.phone || phone || null;
    if (!customerPhone) {
      console.warn('[WalkIn] Token SMS skipped — customer phone not provided.');
    } else if (full?.token) {
      try {
        const [branch, service] = await Promise.all([
          Branch.findByPk(branchId, { attributes: ['name'] }),
          Service.findByPk(full.service_id, { attributes: ['name'] }),
        ]);
        const customerName = full.customer_name || 'Customer';
        const branchName = branch?.name || 'Zane Salon';
        const serviceName = service?.name || 'Service';
        const waitMins = Number(full.estimated_wait || 0);
        const sms =
          `Zane Salon Walk-In Token\n` +
          `Hi ${customerName}, your token is ${full.token}.\n` +
          `Service: ${serviceName}\n` +
          `Branch: ${branchName}\n` +
          (waitMins > 0 ? `Estimated wait: ~${waitMins} min\n` : '') +
          `Please keep this token number.`;
        console.log(`[WalkIn] Sending token SMS → ${customerPhone} (${full.token})`);
        await sendSMS({
          to: customerPhone,
          message: sms,
          meta: {
            customer_name: customerName,
            event_type: 'walkin_token',
            branch_id: Number(branchId) || null,
          },
        });
      } catch (smsErr) {
        console.error('walkin.checkin token sms error:', smsErr.message);
      }
    }

    emitQueueUpdate(branchId, { action: 'checkin', entry: full });
    res.status(201).json(full);
  } catch (err) {
    if (err.status === 404) return res.status(404).json({ message: err.message });
    console.error('walkin.checkin error:', err);
    res.status(500).json({ message: 'Failed to check in walk-in customer.' });
  }
};

// ── PATCH /api/walkin/:id/status ──────────────────────────────────────────────
exports.updateStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const valid = ['serving', 'completed', 'cancelled'];
    if (!valid.includes(status)) {
      return res.status(400).json({ message: `status must be one of: ${valid.join(', ')}` });
    }

    const entry = await WalkIn.findByPk(id);
    if (!entry) return res.status(404).json({ message: 'Walk-in entry not found.' });
    if (req.userBranchId && Number(entry.branch_id) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. Walk-in belongs to a different branch.' });
    }

    entry.status = status;
    if (status === 'serving') {
      entry.serve_start_time = new Date().toTimeString().slice(0, 8);
    }
    await entry.save();

    const full = await WalkIn.findByPk(id, { include: fullWalkInInclude });
    emitQueueUpdate(entry.branch_id, { action: 'statusChange', entry: full });
    res.json(full);
  } catch (err) {
    console.error('walkin.updateStatus error:', err);
    res.status(500).json({ message: 'Failed to update walk-in status.' });
  }
};

// ── PATCH /api/walkin/:id/assign ──────────────────────────────────────────────
exports.assign = async (req, res) => {
  try {
    const { id } = req.params;
    const { staffId } = req.body;

    if (!staffId) return res.status(400).json({ message: 'staffId is required.' });

    const entry = await WalkIn.findByPk(id);
    if (!entry) return res.status(404).json({ message: 'Walk-in entry not found.' });
    if (req.userBranchId && Number(entry.branch_id) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. Walk-in belongs to a different branch.' });
    }

    entry.staff_id = staffId;
    entry.status = 'serving';
    entry.serve_start_time = new Date().toTimeString().slice(0, 8);
    await entry.save();

    const full = await WalkIn.findByPk(id, { include: fullWalkInInclude });
    emitQueueUpdate(entry.branch_id, { action: 'assign', entry: full });
    res.json(full);
  } catch (err) {
    console.error('walkin.assign error:', err);
    res.status(500).json({ message: 'Failed to assign staff.' });
  }
};

// ── PATCH /api/walkin/:id ─────────────────────────────────────────────────────
exports.update = async (req, res) => {
  try {
    const { id } = req.params;
    const { customerName, phone, serviceId, note } = req.body;
    const serviceIds = req.body.serviceIds ?? req.body.service_ids;

    const entry = await WalkIn.findByPk(id);
    if (!entry) return res.status(404).json({ message: 'Walk-in entry not found.' });
    if (req.userBranchId && Number(entry.branch_id) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. Walk-in belongs to a different branch.' });
    }
    if (entry.status === 'completed') {
      return res.status(400).json({ message: 'Completed walk-in entries cannot be edited.' });
    }

    if (customerName != null && !String(customerName).trim()) {
      return res.status(400).json({ message: 'customerName cannot be empty.' });
    }

    const orderedIds = normalizeServiceIdList(serviceIds);
    if (orderedIds.length > 0) {
      const agg = await totalsFromServiceIds(orderedIds);
      entry.service_id = agg.primaryId;
      entry.total_amount = agg.totalAmount;
    } else if (serviceId != null) {
      const service = await Service.findByPk(serviceId);
      if (!service) return res.status(404).json({ message: 'Service not found.' });
      entry.service_id = Number(serviceId);
      entry.total_amount = Number(service.price || 0);
    }

    if (customerName != null) entry.customer_name = String(customerName).trim();
    if (phone !== undefined) entry.phone = phone || null;
    if (note !== undefined) entry.note = note || null;

    await sequelize.transaction(async (t) => {
      await entry.save({ transaction: t });
      if (orderedIds.length > 0) {
        await replaceWalkInQueueServices(entry.id, orderedIds, t);
      } else if (serviceId != null) {
        await replaceWalkInQueueServices(entry.id, [Number(serviceId)], t);
      }
    });

    const full = await WalkIn.findByPk(id, { include: fullWalkInInclude });
    emitQueueUpdate(entry.branch_id, { action: 'update', entry: full });
    res.json(full);
  } catch (err) {
    console.error('walkin.update error:', err);
    res.status(500).json({ message: 'Failed to update walk-in entry.' });
  }
};

// ── DELETE /api/walkin/:id ────────────────────────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { id } = req.params;

    const entry = await WalkIn.findByPk(id);
    if (!entry) return res.status(404).json({ message: 'Walk-in entry not found.' });
    if (req.userBranchId && Number(entry.branch_id) !== Number(req.userBranchId)) {
      return res.status(403).json({ message: 'Access denied. Walk-in belongs to a different branch.' });
    }

    const branchId = entry.branch_id;
    await entry.destroy();

    emitQueueUpdate(branchId, { action: 'remove', id: Number(id) });
    res.json({ message: 'Walk-in entry removed.' });
  } catch (err) {
    console.error('walkin.remove error:', err);
    res.status(500).json({ message: 'Failed to remove walk-in entry.' });
  }
};
