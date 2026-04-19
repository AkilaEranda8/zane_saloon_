'use strict';

const { Router }     = require('express');
const { randomUUID } = require('crypto');
const { verifyToken } = require('../middleware/auth');
const helaPOS         = require('../services/helaPosService');
const { getIO }       = require('../socket');

const router = Router();

// ── POST /api/qr-payment/generate ────────────────────────────────────────────
// Protected (JWT). Generates a dynamic LankaQR code for the given amount.
router.post('/generate', verifyToken, async (req, res) => {
  try {
    const { amount, reference: clientRef } = req.body || {};
    const amountNum = parseFloat(amount);
    if (!amount || isNaN(amountNum) || amountNum <= 0) {
      return res.status(400).json({ message: 'amount must be a positive number.' });
    }
    const reference = clientRef || randomUUID();
    const result = await helaPOS.generateQR({ amount: amountNum, reference });
    return res.json(result);
  } catch (err) {
    console.error('[QR generate]', err.message);
    return res.status(502).json({ message: err.message });
  }
});

// ── POST /api/qr-payment/status ──────────────────────────────────────────────
// Protected (JWT). Polls HelaPOS for the status of a QR payment.
router.post('/status', verifyToken, async (req, res) => {
  try {
    const { reference, qr_reference } = req.body || {};
    if (!reference && !qr_reference) {
      return res.status(400).json({ message: 'reference or qr_reference is required.' });
    }
    const data = await helaPOS.checkStatus({ reference, qr_reference });

    // Normalize common fields expected by clients while preserving full payload.
    const paymentStatus =
      data?.payment_status ??
      data?.sale?.payment_status ??
      data?.data?.payment_status ??
      data?.data?.sale?.payment_status;

    const normalized = {
      ...data,
      ...(paymentStatus !== undefined ? { payment_status: paymentStatus } : {}),
      ...(data?.reference ? { reference: data.reference } : {}),
      ...(data?.qr_reference
        ? { qr_reference: data.qr_reference }
        : data?.sale?.reference_id
          ? { qr_reference: data.sale.reference_id }
          : {}),
    };

    return res.json(normalized);
  } catch (err) {
    console.error('[QR status]', err.message);
    return res.status(502).json({ message: err.message });
  }
});

// ── POST /api/qr-payment/webhook ─────────────────────────────────────────────
// Public (no auth). HelaPOS calls this endpoint when a QR payment completes.
// Must always return 200 OK to acknowledge receipt.
router.post('/webhook', (req, res) => {
  try {
    const payload = req.body || {};
    console.log('[HelaPOS Webhook]', JSON.stringify(payload));

    // Notify mobile apps in real-time via Socket.io
    const io = getIO();
    if (io && payload.reference) {
      io.emit('qr:payment', {
        reference:      payload.reference,
        qr_reference:   payload.sale?.reference_id,
        payment_status: payload.sale?.payment_status,
        amount:         payload.sale?.amount,
        timestamp:      payload.sale?.timestamp,
      });
    }

    return res.status(200).json({ received: true });
  } catch (err) {
    console.error('[HelaPOS Webhook]', err.message);
    // Always return 200 so HelaPOS does not retry
    return res.status(200).json({ received: true });
  }
});

// ── POST /api/qr-payment/history ─────────────────────────────────────────────
// Protected (JWT). Retrieves transaction history for a date range.
router.post('/history', verifyToken, async (req, res) => {
  try {
    const { businessId, start, end } = req.body || {};
    if (!start || !end) {
      return res.status(400).json({ message: 'start and end dates are required (YYYY-MM-DD).' });
    }
    const data = await helaPOS.getTransactionHistory({ businessId, start, end });
    return res.json(data);
  } catch (err) {
    console.error('[QR history]', err.message);
    return res.status(502).json({ message: err.message });
  }
});

// ── POST /api/qr-payment/revoke ──────────────────────────────────────────────
// Protected (JWT). Revokes the HelaPOS session (logout).
router.post('/revoke', verifyToken, async (req, res) => {
  try {
    const data = await helaPOS.revokeSession();
    return res.json(data);
  } catch (err) {
    console.error('[QR revoke]', err.message);
    return res.status(502).json({ message: err.message });
  }
});

module.exports = router;
