#!/bin/bash
# echo ""
# echo "✨ Starting to copy certs over from caddy to mailcow ✨"
# MAILCOW_HOSTNAME=mx1.infra.ijo.no
# CADDY_CERTS_DIR=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory
# MD5SUM_CURRENT_CERT=($(md5sum /opt/mailcow-dockerized/data/assets/ssl/cert.pem))
# MD5SUM_NEW_CERT=($(md5sum $CADDY_CERTS_DIR/$MAILCOW_HOSTNAME/$MAILCOW_HOSTNAME.crt))
#
#         cp $CADDY_CERTS_DIR/$MAILCOW_HOSTNAME/$MAILCOW_HOSTNAME.crt /opt/mailcow-dockerized/data/assets/ssl/cert.pem
#         cp $CADDY_CERTS_DIR/$MAILCOW_HOSTNAME/$MAILCOW_HOSTNAME.key /opt/mailcow-dockerized/data/assets/ssl/key.pem
#         cp $CADDY_CERTS_DIR/$MAILCOW_HOSTNAME/$MAILCOW_HOSTNAME.crt /opt/mailcow-dockerized/data/assets/ssl/$MAILCOW_HOSTNAME/cert.pem
#         cp $CADDY_CERTS_DIR/$MAILCOW_HOSTNAME/$MAILCOW_HOSTNAME.key /opt/mailcow-dockerized/data/assets/ssl/$MAILCOW_HOSTNAME/key.pem
#         postfix_c=$(docker ps -qaf name=postfix-mailcow)
#         dovecot_c=$(docker ps -qaf name=dovecot-mailcow)
#         nginx_c=$(docker ps -qaf name=nginx-mailcow)
#         docker restart ${postfix_c} ${dovecot_c} ${nginx_c}
#
#
set -e

echo ""
echo "✨ Syncing certificates from Caddy → Mailcow..."

MAILCOW_HOSTNAME="mx1.infra.ijo.no"
CADDY_BASE="/var/lib/caddy/.local/share/caddy/certificates"

# --- Locate certificate folder automatically ---
CERT_DIR=$(find "$CADDY_BASE" -type f -name "${MAILCOW_HOSTNAME}.crt" -printf '%h\n' | head -n 1)

if [[ -z "$CERT_DIR" ]]; then
  echo "❌ ERROR: Could not find certificate for $MAILCOW_HOSTNAME in $CADDY_BASE"
  exit 1
fi

CRT="${CERT_DIR}/${MAILCOW_HOSTNAME}.crt"
KEY="${CERT_DIR}/${MAILCOW_HOSTNAME}.key"

# --- Verify files exist ---
if [[ ! -f "$CRT" || ! -f "$KEY" ]]; then
  echo "❌ ERROR: Missing certificate files:"
  ls -lah "$CERT_DIR"
  exit 1
fi

# --- Destination paths ---
DEST="/opt/mailcow-dockerized/data/assets/ssl"
DEST_HOST="${DEST}/${MAILCOW_HOSTNAME}"

mkdir -p "$DEST_HOST"

# --- Compare MD5 hashes ---
if md5sum -c <(md5sum "$CRT" | sed "s|$CRT|$DEST/cert.pem|") 2>/dev/null; then
  echo "✔ No certificate changes detected. Nothing to do."
  exit 0
fi

echo "🔄 Certificate has changed — updating Mailcow certs..."

cp "$CRT" "$DEST/cert.pem"
cp "$KEY" "$DEST/key.pem"
cp "$CRT" "$DEST_HOST/cert.pem"
cp "$KEY" "$DEST_HOST/key.pem"

# --- Restart mailcow services that use certs ---
postfix_c=$(docker ps -qaf name=postfix-mailcow)
dovecot_c=$(docker ps -qaf name=dovecot-mailcow)
nginx_c=$(docker ps -qaf name=nginx-mailcow)

echo "🔁 Restarting Mailcow containers..."
docker restart "$postfix_c" "$dovecot_c" "$nginx_c"

echo "✨ Done. Certs synced and containers restarted."
