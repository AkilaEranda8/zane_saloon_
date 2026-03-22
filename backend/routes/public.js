const express = require('express');
const router = express.Router();
const { Op } = require('sequelize');
const Branch = require('../models/Branch');
const Service = require('../models/Service');
const Staff = require('../models/Staff');
const Appointment = require('../models/Appointment');

// ── GET /api/public/branches — active branches only ──────────────────────────
router.get('/branches', async (req, res) => {
  try {
    const branches = await Branch.findAll({
      where: { status: 'active' },
      attributes: ['id', 'name', 'address', 'phone', 'color'],
      order: [['name', 'ASC']],
    });
    res.json(branches);
  } catch (err) {
    console.error('Public branches error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/public/services — active services only ──────────────────────────
router.get('/services', async (req, res) => {
  try {
    const services = await Service.findAll({
      where: { is_active: true },
      attributes: ['id', 'name', 'category', 'duration_minutes', 'price', 'description'],
      order: [['category', 'ASC'], ['name', 'ASC']],
    });
    res.json(services);
  } catch (err) {
    console.error('Public services error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/public/staff?branchId= — active staff, limited fields ──────────
router.get('/staff', async (req, res) => {
  try {
    const where = { is_active: true };
    if (req.query.branchId) {
      where.branch_id = parseInt(req.query.branchId, 10);
    }
    const staff = await Staff.findAll({
      where,
      attributes: ['id', 'name', 'role_title'],
      order: [['name', 'ASC']],
    });
    res.json(staff);
  } catch (err) {
    console.error('Public staff error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/public/availability?staffId=&date= — booked time slots ─────────
router.get('/availability', async (req, res) => {
  try {
    const { staffId, date } = req.query;
    if (!staffId || !date) {
      return res.status(400).json({ message: 'staffId and date are required' });
    }

    const appointments = await Appointment.findAll({
      where: {
        staff_id: parseInt(staffId, 10),
        date,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
      attributes: ['time'],
    });

    const bookedTimes = appointments.map((a) => a.time.substring(0, 5)); // "HH:MM"
    res.json(bookedTimes);
  } catch (err) {
    console.error('Public availability error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/public/bookings — create appointment (pending) ─────────────────
router.post('/bookings', async (req, res) => {
  try {
    const { branch_id, service_id, staff_id, customer_name, phone, email, date, time, notes } = req.body;

    if (!branch_id || !service_id || !staff_id || !customer_name || !phone || !date || !time) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Fetch service price
    const service = await Service.findByPk(service_id, { attributes: ['price'] });
    if (!service) return res.status(404).json({ message: 'Service not found' });

    // Check for double-booking
    const existing = await Appointment.findOne({
      where: {
        staff_id,
        date,
        time,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
    });
    if (existing) {
      return res.status(409).json({ message: 'This time slot is already booked' });
    }

    const appointment = await Appointment.create({
      branch_id,
      service_id,
      staff_id,
      customer_name: customer_name.trim(),
      phone: phone.trim(),
      date,
      time,
      amount: service.price,
      status: 'pending',
      notes: notes ? notes.trim() : null,
    });

    res.status(201).json({ message: 'Booking created successfully', id: appointment.id });
  } catch (err) {
    console.error('Public booking error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
