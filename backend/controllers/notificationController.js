'use strict';
const { Op } = require('sequelize');
const { NotificationLog, NotificationSettings } = require('../models');
const { sendEmail, sendWhatsApp } = require('../services/notificationService');

const DEFAULT_SETTINGS = {
  appt_confirmed_email:    true,
  appt_confirmed_whatsapp: true,
  payment_receipt_email:   true,
  payment_receipt_whatsapp: true,
  loyalty_points_whatsapp: true,
};

const SETTINGS_FIELDS = Object.keys(DEFAULT_SETTINGS);

// ── GET /api/notifications/log ────────────────────────────────────────────────
const getLogs = async (req, res) => {
  try {
    const limit  = Math.min(parseInt(req.query.limit) || 20, 200);
    const page   = Math.max(parseInt(req.query.page)  || 1, 1);
    const offset = (page - 1) * limit;

    const where = {};
    if (req.userBranchId)         where.branch_id  = req.userBranchId;
    else if (req.query.branchId)  where.branch_id  = req.query.branchId;
    if (req.query.channel)        where.channel    = req.query.channel;
    if (req.query.event_type)     where.event_type = req.query.event_type;
    if (req.query.status)         where.status     = req.query.status;
    if (req.query.from || req.query.to) {
      where.createdAt = {};
      if (req.query.from) where.createdAt[Op.gte] = new Date(req.query.from);
      if (req.query.to)   where.createdAt[Op.lte] = new Date(req.query.to + 'T23:59:59');
    }

    const { count, rows } = await NotificationLog.findAndCountAll({
      where, limit, offset,
      order: [['createdAt', 'DESC']],
    });

    return res.json({ total: count, page, limit, data: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

// ── GET /api/notifications/settings ──────────────────────────────────────────
const getSettings = async (req, res) => {
  try {
    const row = await NotificationSettings.findOne({ where: { branch_id: null } });
    if (!row) return res.json(DEFAULT_SETTINGS);

    const out = {};
    for (const f of SETTINGS_FIELDS) out[f] = row[f];
    return res.json(out);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

// ── PUT /api/notifications/settings ──────────────────────────────────────────
const updateSettings = async (req, res) => {
  try {
    const update = {};
    for (const f of SETTINGS_FIELDS) {
      if (typeof req.body[f] === 'boolean') update[f] = req.body[f];
    }

    const [row, created] = await NotificationSettings.findOrCreate({
      where:    { branch_id: null },
      defaults: { ...DEFAULT_SETTINGS, ...update },
    });

    if (!created) await row.update(update);

    const out = {};
    for (const f of SETTINGS_FIELDS) out[f] = (created ? { ...DEFAULT_SETTINGS, ...update } : row)[f];
    return res.json(out);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

// ── POST /api/notifications/test ──────────────────────────────────────────────
const sendTest = async (req, res) => {
  try {
    const { event_type = 'appointment_confirmed', email, phone } = req.body;
    const branchId = req.userBranchId || req.user.branchId || null;

    const VALID = ['appointment_confirmed', 'payment_receipt', 'loyalty_points'];
    if (!VALID.includes(event_type)) {
      return res.status(400).json({ message: `event_type must be one of: ${VALID.join(', ')}` });
    }
    if (!email && !phone) {
      return res.status(400).json({ message: 'Provide at least one of: email, phone.' });
    }

    const meta = {
      customer_name: 'Test Customer',
      event_type:    'test',
      branch_id:     branchId,
    };
    const date = new Date().toISOString().slice(0, 10);

    if (event_type === 'appointment_confirmed') {
      if (email) {
        await sendEmail({
          to:      email,
          subject: '[TEST] Appointment Confirmed — Zane Salon',
          html:    `<p>This is a test appointment confirmation from Zane Salon (${date}).</p>`,
          meta,
        });
      }
      if (phone) {
        await sendWhatsApp({
          to:      phone,
          message: `[TEST] ✂️ Zane Salon — Appointment Confirmed!\n\nHi Test Customer, this is a test notification (${date}).`,
          meta,
        });
      }
    } else if (event_type === 'payment_receipt') {
      if (email) {
        await sendEmail({
          to:      email,
          subject: '[TEST] Payment Receipt — Zane Salon',
          html:    `<p>This is a test payment receipt from Zane Salon (${date}). Amount: Rs. 1,500.00</p>`,
          meta,
        });
      }
      if (phone) {
        await sendWhatsApp({
          to:      phone,
          message: `[TEST] 🧾 Zane Salon — Payment Receipt\n\nHi Test Customer! This is a test receipt (${date}).\n💰 Total Paid: Rs. 1,500.00`,
          meta,
        });
      }
    } else if (event_type === 'loyalty_points') {
      if (phone) {
        await sendWhatsApp({
          to:      phone,
          message: `[TEST] 🌟 Zane Salon — Loyalty Points\n\nHey Test Customer! 🎉\nThis is a test loyalty update.\n• Earned this visit: +150 pts\n• Total balance: 350 pts`,
          meta,
        });
      }
    }

    return res.json({ message: `Test notifications dispatched for "${event_type}".` });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = { getLogs, getSettings, updateSettings, sendTest };
