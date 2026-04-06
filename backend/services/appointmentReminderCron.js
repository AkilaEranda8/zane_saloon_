'use strict';

const cron = require('node-cron');
const { Op } = require('sequelize');
const { sendToTokens } = require('./fcmService');

let _models = null;
function getModels() {
  if (!_models) _models = require('../models');
  return _models;
}

/**
 * Resolves the FCM tokens to notify for an appointment.
 *
 * - If the appointment has an assigned staff member, notify ONLY that staff
 *   member's linked user token.
 * - If no staff is assigned, fall back to all tokens for the branch.
 */
async function _resolveTokens(appt, StaffFcmToken, Staff) {
  if (appt.staff_id) {
    // Staff.user_id → StaffFcmToken.user_id  (User has no staff_id column)
    const staff = await Staff.findByPk(appt.staff_id, { attributes: ['id', 'user_id'] });
    if (staff && staff.user_id) {
      const row = await StaffFcmToken.findOne({
        where: { user_id: staff.user_id },
        attributes: ['fcm_token'],
      });
      if (row) return [row.fcm_token];
    }
    // Staff assigned but no linked user / token registered — no notification
    return [];
  }

  // No staff assigned → notify everyone registered for this branch
  const rows = await StaffFcmToken.findAll({
    where: { branch_id: appt.branch_id },
    attributes: ['fcm_token'],
  });
  return rows.map((r) => r.fcm_token);
}

/**
 * Runs every minute. Finds appointments starting in ~15 minutes
 * (window: 14–16 min from now) with status pending/confirmed,
 * then sends FCM push notifications to the assigned staff member only
 * (or all branch staff if no one is assigned).
 */
function startAppointmentReminderCron() {
  cron.schedule('* * * * *', async () => {
    try {
      const { Appointment, Service, StaffFcmToken, Staff } = getModels();

      const now = new Date();

      const windowStart = new Date(now.getTime() + 14 * 60 * 1000);
      const windowEnd   = new Date(now.getTime() + 16 * 60 * 1000);

      const pad = (n) => String(n).padStart(2, '0');
      const todayStr  = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
      const toTimeStr = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;

      const appointments = await Appointment.findAll({
        where: {
          date:   todayStr,
          time:   { [Op.between]: [toTimeStr(windowStart), toTimeStr(windowEnd)] },
          status: { [Op.in]: ['pending', 'confirmed'] },
        },
        include: [
          { model: Service, as: 'service', attributes: ['name'] },
        ],
      });

      if (appointments.length === 0) return;

      for (const appt of appointments) {
        const timeLabel = appt.time ? String(appt.time).slice(0, 5) : '';
        const svcName   = appt.service?.name || 'Appointment';

        const tokens = await _resolveTokens(appt, StaffFcmToken, Staff);
        if (tokens.length === 0) continue;

        const title = `⏰ Upcoming Appointment in 15 min`;
        const body  = `${appt.customer_name} — ${svcName} at ${timeLabel}`;

        await sendToTokens(tokens, title, body, {
          type:           'appointment_reminder',
          appointment_id: String(appt.id),
          branch_id:      String(appt.branch_id),
          customer_name:  appt.customer_name,
          service:        svcName,
          time:           timeLabel,
          date:           appt.date,
        });

        const target = appt.staff_id ? `staff #${appt.staff_id}` : `branch #${appt.branch_id} (all)`;
        console.log(`[ReminderCron] Sent reminder for appointment #${appt.id} → ${target} (${tokens.length} device(s))`);
      }
    } catch (err) {
      console.error('[ReminderCron] Error:', err.message);
    }
  });

  console.log('✓ Appointment reminder cron started (runs every minute).');
}

/**
 * Runs every day at 09:00. Finds all Reminders with due_date = today
 * that are not yet done, grouped by branch, and sends a push to each branch.
 */
function startReminderDueCron() {
  cron.schedule('0 9 * * *', async () => {
    try {
      const { Reminder, StaffFcmToken } = getModels();

      const now    = new Date();
      const pad    = (n) => String(n).padStart(2, '0');
      const today  = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;

      const reminders = await Reminder.findAll({
        where: { due_date: today, is_done: false },
        attributes: ['id', 'branch_id', 'title', 'type', 'priority'],
      });

      if (reminders.length === 0) return;

      // Group by branch
      const byBranch = {};
      for (const r of reminders) {
        if (!byBranch[r.branch_id]) byBranch[r.branch_id] = [];
        byBranch[r.branch_id].push(r);
      }

      const typeEmoji = { general: '📝', inventory: '📦', staff: '👤', customer: '👥' };

      for (const [branchId, items] of Object.entries(byBranch)) {
        const rows = await StaffFcmToken.findAll({
          where: { branch_id: branchId },
          attributes: ['fcm_token'],
        });
        const tokens = rows.map((r) => r.fcm_token).filter(Boolean);
        if (tokens.length === 0) continue;

        if (items.length === 1) {
          const r     = items[0];
          const emoji = typeEmoji[r.type] || '📝';
          await sendToTokens(tokens, `${emoji} Reminder Due Today`, r.title, {
            type:        'reminder_due',
            reminder_id: String(r.id),
            branch_id:   String(branchId),
          });
        } else {
          const titles = items.slice(0, 3).map((r) => `• ${r.title}`).join('\n');
          const extra  = items.length > 3 ? `\n+${items.length - 3} more` : '';
          await sendToTokens(tokens, `📋 ${items.length} Reminders Due Today`, `${titles}${extra}`, {
            type:      'reminder_due',
            branch_id: String(branchId),
          });
        }

        console.log(`[ReminderDueCron] Sent ${items.length} due reminder(s) to branch #${branchId} (${tokens.length} device(s))`);
      }
    } catch (err) {
      console.error('[ReminderDueCron] Error:', err.message);
    }
  });

  console.log('✓ Reminder due-today cron started (runs daily at 09:00).');
}

module.exports = { startAppointmentReminderCron, startReminderDueCron };
