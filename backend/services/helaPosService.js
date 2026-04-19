'use strict';

/**
 * helaPosService.js — HelaPOS LankaQR API integration
 * Base URL: https://helapos.lk/merchant-api
 *
 * Required env vars:
 *   HELAPOS_APP_ID        — HelaPOS App ID
 *   HELAPOS_APP_SECRET    — HelaPOS App Secret
 *   HELAPOS_BUSINESS_ID   — Merchant Business ID in HelaPOS
 *   HELAPOS_BASE_URL      — (optional) override base URL
 */

const BASE_URL = () =>
  String(process.env.HELAPOS_BASE_URL || 'https://helapos.lk/merchant-api').replace(/\/+$/, '');

// ── In-memory token cache ─────────────────────────────────────────────────────
let _accessToken    = null;
let _refreshToken   = null;
let _tokenExpiresAt = 0;

function _authCandidates() {
  const appId = String(process.env.HELAPOS_APP_ID || '').trim();
  const businessUserId = String(process.env.HELAPOS_BUSINESS_USER_ID || '').trim();
  const sec = String(process.env.HELAPOS_APP_SECRET || '').trim();
  if (!sec) return [];

  const ids = [];
  if (appId) ids.push(appId);
  if (businessUserId && businessUserId !== appId) ids.push(businessUserId);

  return ids.map((id) => ({
    id,
    code: Buffer.from(`${id}:${sec}`).toString('base64'),
  }));
}

async function _post(endpoint, body, extraHeaders = {}) {
  const res = await fetch(`${BASE_URL()}${endpoint}`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', ...extraHeaders },
    body:    JSON.stringify(body),
  });
  return res.json();
}

async function _getToken() {
  // Return cached token if still valid (60-second buffer)
  if (_accessToken && Date.now() < _tokenExpiresAt - 60_000) return _accessToken;

  // Attempt token refresh first
  if (_refreshToken) {
    try {
      const data = await _post('/merchant/api/v1/merchant/auth/refresh', {
        refreshToken: _refreshToken,
      });
      if (data.code === 200 && data.data?.[0]?.accessToken) {
        _accessToken    = data.data[0].accessToken;
        _refreshToken   = data.data[0].refreshToken;
        _tokenExpiresAt = Date.now() + 25 * 60 * 1000;
        return _accessToken;
      }
    } catch (_) { /* fall through to fresh login */ }
  }

  // Fresh token via Basic auth. Prefer App ID, then fallback to Business User ID.
  const candidates = _authCandidates();
  if (candidates.length === 0) {
    throw new Error(
      'Set HELAPOS_APP_SECRET and either HELAPOS_APP_ID or HELAPOS_BUSINESS_USER_ID env variables.',
    );
  }

  let lastError = 'Unknown HelaPOS auth error';
  for (const candidate of candidates) {
    const data = await _post(
      '/merchant/api/v1/getToken',
      { grant_type: 'client_credentials' },
      { Authorization: `Basic ${candidate.code}` },
    );

    if (data.code === 200 && data.accessToken) {
      _accessToken    = data.accessToken;
      _refreshToken   = data.refreshToken;
      _tokenExpiresAt = Date.now() + 25 * 60 * 1000;
      return _accessToken;
    }

    lastError = data.statusMessage || data.message || JSON.stringify(data);
  }

  throw new Error(`HelaPOS getToken failed: ${lastError}`);
}

/**
 * Generate a dynamic LankaQR code.
 *
 * @param {{ amount: number|string, reference: string }} opts
 * @returns {Promise<{ qr_data: string, qr_reference: string, reference: string }>}
 */
async function generateQR({ amount, reference }) {
  const businessId = process.env.HELAPOS_BUSINESS_ID || '';
  if (!businessId) {
    throw new Error('HELAPOS_BUSINESS_ID env variable is not set.');
  }

  const token = await _getToken();
  const data  = await _post(
    '/merchant/api/helapos/qr/generate',
    { b: businessId, r: String(reference), am: parseFloat(amount) },
    { Authorization: `Bearer ${token}` },
  );

  if (String(data.statusCode) !== '200') {
    throw new Error(data.statusMessage || 'HelaPOS QR generation failed');
  }

  return {
    // Keep both keys for compatibility with existing mobile clients.
    qr_data:       data.qr_data,
    qr_string:     data.qr_data,
    qr_reference:  data.qr_reference,
    reference:     data.reference || reference,
  };
}

/**
 * Check the payment status of a QR transaction.
 *
 * @param {{ reference?: string, qr_reference?: string }} opts
 * @returns {Promise<object>} HelaPOS sale status response
 */
async function checkStatus({ reference, qr_reference } = {}) {
  const token = await _getToken();
  const body  = {};
  if (reference)    body.reference    = reference;
  if (qr_reference) body.qr_reference = qr_reference;

  return _post(
    '/merchant/api/helapos/sales/getSaleStatus',
    body,
    { Authorization: `Bearer ${token}` },
  );
}

/**
 * Retrieve transaction history for a date range.
 *
 * @param {{ businessId?: string, start: string, end: string }} opts
 *   - businessId defaults to HELAPOS_BUSINESS_ID env var
 *   - start/end in YYYY-MM-DD format
 * @returns {Promise<object>} HelaPOS sales list response
 */
async function getTransactionHistory({ businessId, start, end } = {}) {
  const biz = businessId || process.env.HELAPOS_BUSINESS_ID || '';
  if (!biz) {
    throw new Error('HELAPOS_BUSINESS_ID env variable is not set.');
  }
  if (!start || !end) {
    throw new Error('start and end dates are required (YYYY-MM-DD).');
  }

  const token = await _getToken();
  return _post(
    '/merchant/api/helapos/sales',
    { businessId: biz, start, end },
    { Authorization: `Bearer ${token}` },
  );
}

/**
 * Revoke the current session (logout).
 * Clears the in-memory token cache so the next call forces a fresh login.
 *
 * @returns {Promise<object>} HelaPOS logout response
 */
async function revokeSession() {
  if (!_refreshToken) {
    return { code: 200, message: 'No active session to revoke', data: null };
  }

  const token = await _getToken();
  const data  = await _post(
    '/merchant/api/v1/merchant/auth/logout',
    { refreshToken: _refreshToken },
    { Authorization: `Bearer ${token}` },
  );

  // Clear cached tokens regardless of response
  _accessToken    = null;
  _refreshToken   = null;
  _tokenExpiresAt = 0;

  return data;
}

module.exports = { generateQR, checkStatus, getTransactionHistory, revokeSession };
