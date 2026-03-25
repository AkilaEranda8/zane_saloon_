#!/bin/bash
# ── SSL initialization script for xanesalon.com ──────────────────────────────
# Run this ONCE on the VPS to obtain Let's Encrypt certificates.
# After that, a cron job handles auto-renewal.
#
# Subdomains covered:
#   xanesalon.com         → Public website
#   www.xanesalon.com     → Public website (redirects to non-www)
#   main.xanesalon.com    → Management system
#   api.xanesalon.com     → Backend API
#   pma.xanesalon.com     → phpMyAdmin

set -e

DOMAIN="xanesalon.com"
EMAIL="akilaeranda8@gmail.com"
COMPOSE="docker compose"

echo "=== Step 1: Create temporary HTTP-only nginx config ==="
cat > /tmp/default_http.conf << 'HTTPCONF'
server {
    listen 80;
    server_name xanesalon.com www.xanesalon.com main.xanesalon.com api.xanesalon.com pma.xanesalon.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'SSL setup in progress...';
        add_header Content-Type text/plain;
    }
}
HTTPCONF

echo "=== Step 2: Stop proxy, use temp config ==="
$COMPOSE stop proxy
cp proxy/default.conf proxy/default.conf.ssl.bak
cp /tmp/default_http.conf proxy/default.conf
$COMPOSE up -d proxy
sleep 5

echo "=== Step 3: Request wildcard + root certificates ==="
$COMPOSE run --rm --profile certbot certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN" \
  -d "www.$DOMAIN" \
  -d "main.$DOMAIN" \
  -d "api.$DOMAIN" \
  -d "pma.$DOMAIN"

echo "=== Step 4: Restore full SSL nginx config ==="
cp proxy/default.conf.ssl.bak proxy/default.conf
rm -f proxy/default.conf.ssl.bak

echo "=== Step 5: Reload proxy with SSL ==="
$COMPOSE stop proxy
$COMPOSE up -d proxy

echo "=== Step 6: Set up auto-renewal cron ==="
CRON_CMD="0 3 * * * cd /root/xanesalon && $COMPOSE run --rm --profile certbot certbot renew --quiet && $COMPOSE exec proxy nginx -s reload"
(crontab -l 2>/dev/null | grep -v certbot; echo "$CRON_CMD") | crontab -

echo ""
echo "=== ✅ SSL setup complete! ==="
echo "  https://xanesalon.com          → Public Website"
echo "  https://www.xanesalon.com      → Public Website (redirects)"
echo "  https://main.xanesalon.com     → Management System"
echo "  https://api.xanesalon.com      → Backend API"
echo "  https://pma.xanesalon.com      → phpMyAdmin"
echo ""
echo "Auto-renewal cron installed (daily at 3 AM)."
