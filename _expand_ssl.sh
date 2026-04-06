#!/bin/bash
# ── Expand SSL cert to include zanesalon.com and www.zanesalon.com ─────────────
# Run this ONCE on the VPS after the website container is deployed.
# DNS: zanesalon.com and www.zanesalon.com must point to this server's IP.

set -e

EMAIL="akilaeranda8@gmail.com"
COMPOSE="docker compose"

echo "=== Expanding SSL cert to include zanesalon.com + www.zanesalon.com ==="
$COMPOSE run --rm --profile certbot certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  --expand \
  -d main.zanesalon.com \
  -d api.zanesalon.com \
  -d pma.zanesalon.com \
  -d zanesalon.com \
  -d www.zanesalon.com

echo "=== Reloading proxy ==="
$COMPOSE exec proxy nginx -s reload

echo ""
echo "=== Done! SSL now covers: ==="
echo "  https://zanesalon.com"
echo "  https://www.zanesalon.com"
echo "  https://main.zanesalon.com"
