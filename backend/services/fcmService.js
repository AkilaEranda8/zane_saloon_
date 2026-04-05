'use strict';

let _admin = null;

function getAdmin() {
  if (_admin) return _admin;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    console.warn('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled.');
    return null;
  }

  try {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    _admin = admin;
    return _admin;
  } catch (err) {
    console.error('[FCM] Failed to initialise Firebase Admin:', err.message);
    return null;
  }
}

/**
 * Send a push notification to a single FCM token.
 * @param {string} token  - FCM device token
 * @param {string} title  - Notification title
 * @param {string} body   - Notification body
 * @param {object} data   - Optional key-value data payload (string values only)
 */
async function sendToToken(token, title, body, data = {}) {
  const admin = getAdmin();
  if (!admin) return;

  const stringData = {};
  for (const [k, v] of Object.entries(data)) {
    stringData[k] = String(v);
  }

  try {
    const message = {
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'appointment_reminders',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };
    await admin.messaging().send(message);
    console.log(`[FCM] Notification sent to token: ${token.slice(0, 20)}...`);
  } catch (err) {
    console.error('[FCM] Send failed:', err.message);
    if (
      err.code === 'messaging/invalid-registration-token' ||
      err.code === 'messaging/registration-token-not-registered'
    ) {
      await removeStaleToken(token);
    }
  }
}

/**
 * Send a push notification to multiple FCM tokens.
 * @param {string[]} tokens
 * @param {string} title
 * @param {string} body
 * @param {object} data
 */
async function sendToTokens(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return;
  await Promise.all(tokens.map((t) => sendToToken(t, title, body, data)));
}

async function removeStaleToken(token) {
  try {
    let _models = require('../models');
    await _models.StaffFcmToken.destroy({ where: { fcm_token: token } });
    console.log('[FCM] Stale token removed.');
  } catch (err) {
    console.error('[FCM] Failed to remove stale token:', err.message);
  }
}

module.exports = { sendToToken, sendToTokens };
