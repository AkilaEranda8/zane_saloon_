'use strict';
const { Op } = require('sequelize');

/**
 * Create the next recurring appointment (weekly) after one is completed.
 * Returns the new appointment or null if the slot is unavailable.
 */
async function createNextRecurring(appointment) {
  try {
    const { Appointment, Branch, Service } = require('../models');
    const { notifyAppointmentConfirmed } = require('./notificationService');

    if (!appointment.is_recurring) return null;

    // Calculate next date (+7 days)
    const currentDate = new Date(appointment.date);
    currentDate.setDate(currentDate.getDate() + 7);
    const nextDate = currentDate.toISOString().slice(0, 10);

    // Check staff availability for the same time slot
    if (appointment.staff_id) {
      const conflict = await Appointment.findOne({
        where: {
          staff_id: appointment.staff_id,
          date: nextDate,
          time: appointment.time,
          status: { [Op.notIn]: ['cancelled'] },
        },
      });
      if (conflict) {
        console.log(`Slot unavailable for recurring appointment: staff ${appointment.staff_id} on ${nextDate} at ${appointment.time}`);
        return null;
      }
    }

    // Determine the root parent id
    const parentId = appointment.recurrence_parent_id || appointment.id;

    // Create the next appointment
    const nextAppt = await Appointment.create({
      branch_id: appointment.branch_id,
      customer_id: appointment.customer_id,
      staff_id: appointment.staff_id,
      service_id: appointment.service_id,
      customer_name: appointment.customer_name,
      phone: appointment.phone,
      date: nextDate,
      time: appointment.time,
      amount: appointment.amount,
      notes: appointment.notes,
      status: 'confirmed',
      is_recurring: true,
      recurrence_frequency: 'weekly',
      recurrence_parent_id: parentId,
    });

    // Link current appointment to the new one
    await appointment.update({ next_appointment_id: nextAppt.id });

    // Send confirmation notification (fire-and-forget)
    if (appointment.phone) {
      const [branch, service] = await Promise.all([
        Branch.findByPk(appointment.branch_id, { attributes: ['id', 'name', 'phone'] }),
        Service.findByPk(appointment.service_id, { attributes: ['id', 'name'] }),
      ]);
      notifyAppointmentConfirmed(nextAppt, branch, service);
    }

    return nextAppt;
  } catch (err) {
    console.error('Error creating next recurring appointment:', err);
    return null;
  }
}

module.exports = { createNextRecurring };
