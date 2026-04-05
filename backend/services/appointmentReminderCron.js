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
 * Runs every minute. Finds appointments starting in ~15 minutes
 * (window: 14–16 min from now) with status pending/confirmed,
 * then sends FCM push notifications to all staff in that branch.
 */
function startAppointmentReminderCron() {
  cron.schedule('* * * * *', async () => {
    try {
      const { Appointment, Service, StaffFcmToken } = getModels();

      const now = new Date();

      // Build the target window: now+14 to now+16 minutes
      const windowStart = new Date(now.getTime() + 14 * 60 * 1000);
      const windowEnd   = new Date(now.getTime() + 16 * 60 * 1000);

      const pad = (n) => String(n).padStart(2, '0');
      const todayStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;

      // Format as HH:MM:SS for comparison with TIME column (local time)
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
        const branchId = appt.branch_id;
        const timeLabel = appt.time ? String(appt.time).slice(0, 5) : '';
        const svcName   = appt.service?.name || 'Appointment';

        // Fetch tokens for this branch + tokens with no branch (admin/superadmin)
        const tokenRows = await StaffFcmToken.findAll({
          where: {
            [Op.or]: [
              { branch_id: branchId },
              { branch_id: null },
            ],
          },
          attributes: ['fcm_token'],
        });

        if (tokenRows.length === 0) continue;

        const tokens = tokenRows.map((r) => r.fcm_token);

        const title = `⏰ Upcoming Appointment in 15 min`;
        const body  = `${appt.customer_name} — ${svcName} at ${timeLabel}`;

        await sendToTokens(tokens, title, body, {
          type:           'appointment_reminder',
          appointment_id: String(appt.id),
          branch_id:      String(branchId),
          customer_name:  appt.customer_name,
          service:        svcName,
          time:           timeLabel,
          date:           appt.date,
        });

        console.log(`[ReminderCron] Sent reminder for appointment #${appt.id} to ${tokens.length} device(s)`);
      }
    } catch (err) {
      console.error('[ReminderCron] Error:', err.message);
    }
  });

  console.log('✓ Appointment reminder cron started (runs every minute).');
}

module.exports = { startAppointmentReminderCron };
