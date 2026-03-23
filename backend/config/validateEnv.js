/**
 * validateEnv.js — Check all required environment variables on startup.
 * Throws with a clear message if any are missing.
 */
function validateEnv() {
  const required = [
    'DB_HOST',
    'DB_USER',
    'DB_PASS',
    'DB_NAME',
    'JWT_SECRET',
  ];

  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables:\n` +
      missing.map((k) => `  - ${k}`).join('\n') +
      `\n\nCreate a .env file in the backend/ folder. See README.md for the template.`
    );
  }

  // Warn about defaults
  if (process.env.JWT_SECRET === 'zanesalon_jwt_secret_key_change_in_production') {
    console.warn('⚠  WARNING: Using default JWT_SECRET. Change it for production!');
  }
}

module.exports = validateEnv;
