'use strict';

const { Router }     = require('express');
const { randomUUID } = require('crypto');
const { verifyToken } = require('../middleware/auth');
const helaPOS         = require('../services/helaPosService');
const { getIO }       = require('../socket');

const router = Router();
const webhookStatusCache = new Map();
const WEBHOOK_CACHE_TTL_MS = 20 * 60 * 1000;

function cacheKey(key) {
  return String(key || '').trim();
}

function putWebhookStatus(key, status) {
  const k = cacheKey(key);
  if (!k || status === undefined || status === null) return;
  webhookStatusCache.set(k, { status, ts: Date.now() });
}

function getWebhookStatus(key) {
  const k = cacheKey(key);
  if (!k) return undefined;

  const hit = webhookStatusCache.get(k);
  if (!hit) return undefined;
  if (Date.now() - hit.ts > WEBHOOK_CACHE_TTL_MS) {
    webhookStatusCache.delete(k);
    return undefined;
  }
  return hit.status;
}

function sweepWebhookStatusCache() {
  const now = Date.now();
  for (const [k, v] of webhookStatusCache.entries()) {
    if (now - v.ts > WEBHOOK_CACHE_TTL_MS) webhookStatusCache.delete(k);
  }
}

function collectStatusCandidates(obj, out, depth = 0) {
  if (obj === null || obj === undefined || depth > 4) return;

  if (typeof obj === 'string' || typeof obj === 'number' || typeof obj === 'boolean') {
    out.push(obj);
    return;
  }

  if (Array.isArray(obj)) {
    for (const item of obj) collectStatusCandidates(item, out, depth + 1);
    return;
  }

  if (typeof obj === 'object') {
    const prioritizedKeys = [
      'payment_status',
      'paymentStatus',
      'status',
      'statusMessage',
      'message',
      'result',
      'description',
      'remark',
      'remarks',
      'sale_status',
      'saleStatus',
      'transaction_status',
      'transactionStatus',
      'isPaid',
      'paid',
      'success',
    ];

    for (const key of prioritizedKeys) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) out.push(obj[key]);
    }

    for (const value of Object.values(obj)) collectStatusCandidates(value, out, depth + 1);
  }
}

function normalizePaymentStatus(data) {
  const valueCandidates = [
    data?.payment_status,
    data?.sale?.payment_status,
    data?.sale?.status,
    data?.sale?.statusMessage,
    data?.data?.payment_status,
    data?.data?.status,
    data?.data?.statusMessage,
    data?.data?.sale?.payment_status,
    data?.data?.sale?.status,
    data?.data?.sale?.statusMessage,
    data?.data?.sale?.payment_status,
    data?.status,
    data?.sale?.status,
    data?.data?.status,
    data?.statusMessage,
    data?.message,
    Array.isArray(data?.data) ? data.data[0]?.payment_status : undefined,
    Array.isArray(data?.data) ? data.data[0]?.status : undefined,
    Array.isArray(data?.data) ? data.data[0]?.statusMessage : undefined,
    Array.isArray(data?.data) ? data.data[0]?.message : undefined,
    Array.isArray(data?.data) ? data.data[0]?.sale?.payment_status : undefined,
    Array.isArray(data?.data) ? data.data[0]?.sale?.status : undefined,
    Array.isArray(data?.data) ? data.data[0]?.sale?.statusMessage : undefined,
  ];

  collectStatusCandidates(data, valueCandidates);

  for (const raw of valueCandidates) {
    if (raw === null || raw === undefined) continue;

    if (typeof raw === 'boolean') {
      return raw ? 2 : -1;
    }

    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return raw;
    }

    if (typeof raw === 'string') {
      const asNumber = Number.parseInt(raw, 10);
      if (Number.isFinite(asNumber)) return asNumber;

      const normalized = raw.trim().toUpperCase();
      if (!normalized) continue;

      if (
        normalized.includes('SUCCESS') ||
        normalized.includes('COMPLET') ||
        normalized.includes('PAID') ||
        normalized.includes('APPROV')
      ) {
        return 2;
      }

      if (
        normalized.includes('FAIL') ||
        normalized.includes('DECLIN') ||
        normalized.includes('REJECT') ||
        normalized.includes('CANCEL') ||
        normalized.includes('VOID') ||
        normalized.includes('EXPIRE') ||
        normalized.includes('TIMEOUT')
      ) {
        return -1;
      }

      if (
        normalized.includes('PEND') ||
        normalized.includes('WAIT') ||
        normalized.includes('PROCESS') ||
        normalized.includes('INITIAT')
      ) {
        return 0;
      }
    }
  }

  return undefined;
}

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
// Uses aggressive caching to avoid HelaPOS rate-limiting.

// Cache for HelaPOS status responses (separate from webhook cache)
const statusResponseCache = new Map();
const STATUS_CACHE_TTL_MS = 8_000; // Don't re-query HelaPOS within 8 seconds

function getCachedStatusResponse(key) {
  const k = cacheKey(key);
  if (!k) return undefined;
  const hit = statusResponseCache.get(k);
  if (!hit) return undefined;
  if (Date.now() - hit.ts > STATUS_CACHE_TTL_MS) {
    statusResponseCache.delete(k);
    return undefined;
  }
  return hit;
}

function putStatusResponseCache(key, data, paymentStatus) {
  const k = cacheKey(key);
  if (!k) return;
  statusResponseCache.set(k, { data, paymentStatus, ts: Date.now() });
}

// In-flight guard: only one HelaPOS call per reference at a time
const inFlightStatusChecks = new Map();

router.post('/status', verifyToken, async (req, res) => {
  try {
    const { reference, qr_reference } = req.body || {};
    if (!reference && !qr_reference) {
      return res.status(400).json({ message: 'reference or qr_reference is required.' });
    }
    sweepWebhookStatusCache();

    // 1) If webhook already confirmed success/failure, return immediately (no HelaPOS call)
    const cachedStatus = getWebhookStatus(reference) ?? getWebhookStatus(qr_reference);
    if (cachedStatus === 2 || cachedStatus === -1) {
      return res.json({
        statusCode: '200',
        payment_status: cachedStatus,
        reference: reference || '',
        qr_reference: qr_reference || '',
        source: 'webhook',
      });
    }

    // 2) Return cached HelaPOS response if still fresh (avoid hammering the API)
    const cachedResp = getCachedStatusResponse(reference) || getCachedStatusResponse(qr_reference);
    if (cachedResp) {
      return res.json({
        ...cachedResp.data,
        payment_status: cachedResp.paymentStatus ?? 0,
        source: 'cache',
      });
    }

    // 3) Deduplicate in-flight requests for the same reference
    const flightKey = cacheKey(reference || qr_reference);
    if (inFlightStatusChecks.has(flightKey)) {
      // Another request is already checking — return pending
      return res.json({
        statusCode: '200',
        payment_status: 0,
        reference: reference || '',
        qr_reference: qr_reference || '',
        source: 'in_flight',
      });
    }

    // 4) Call HelaPOS (only ONE query, prefer qr_reference)
    inFlightStatusChecks.set(flightKey, true);
    let data = null;
    let paymentStatus;

    try {
      const query = qr_reference ? { qr_reference } : { reference };
      data = await helaPOS.checkStatus(query);
      paymentStatus = normalizePaymentStatus(data);
    } catch (err) {
      // Rate-limited or network error — return pending, don't fail
      console.warn('[QR status] HelaPOS call failed:', err.message);
      return res.json({
        statusCode: '200',
        payment_status: 0,
        reference: reference || '',
        qr_reference: qr_reference || '',
        source: 'fallback',
      });
    } finally {
      inFlightStatusChecks.delete(flightKey);
    }

    // Cache the response
    if (reference) putStatusResponseCache(reference, data, paymentStatus);
    if (qr_reference) putStatusResponseCache(qr_reference, data, paymentStatus);

    // Also update webhook cache if terminal status
    if (paymentStatus === 2 || paymentStatus === -1) {
      putWebhookStatus(reference, paymentStatus);
      putWebhookStatus(qr_reference, paymentStatus);
    }

    const finalStatus = paymentStatus ?? 0;
    const normalized = {
      ...data,
      payment_status: finalStatus,
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

    const webhookStatus = normalizePaymentStatus(payload);
    const webhookReference = payload.reference || payload.sale?.reference || payload.data?.reference;
    const webhookQrReference =
      payload.qr_reference ||
      payload.sale?.reference_id ||
      payload.data?.qr_reference ||
      payload.data?.sale?.reference_id;

    putWebhookStatus(webhookReference, webhookStatus);
    putWebhookStatus(webhookQrReference, webhookStatus);

    // Notify mobile apps in real-time via Socket.io
    const io = getIO();
    if (io && (webhookReference || webhookQrReference)) {
      io.emit('qr:payment', {
        reference:      webhookReference,
        qr_reference:   webhookQrReference,
        payment_status: webhookStatus ?? payload.sale?.payment_status,
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
