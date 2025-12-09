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
echo ""
echo "✨ Starting to copy certs over from caddy to mailcow ✨"

MAILCOW_HOSTNAME=mx1.infra.ijo.no
CADDY_BASE=/var/lib/caddy/.local/share/caddy/certificates

# --- Dynamically locate certificate directory ---
CERT_DIR=$(find "$CADDY_BASE" -type f -name "${MAILCOW_HOSTNAME}.crt" -printf '%h' | head -n 1)

if [[ -z "$CERT_DIR" ]]; then
  echo "❌ ERROR: Could not locate certificate directory for $MAILCOW_HOSTNAME"
  exit 1
fi

CRT="$CERT_DIR/$MAILCOW_HOSTNAME.crt"
KEY="$CERT_DIR/$MAILCOW_HOSTNAME.key"

# --- MD5 sums (unchanged) ---
MD5SUM_CURRENT_CERT=($(md5sum /opt/mailcow-dockerized/data/assets/ssl/cert.pem 2>/dev/null))
MD5SUM_NEW_CERT=($(md5sum "$CRT"))

# --- Copy certificates (unchanged) ---
cp "$CRT" /opt/mailcow-dockerized/data/assets/ssl/cert.pem
cp "$KEY" /opt/mailcow-dockerized/data/assets/ssl/key.pem
cp "$CRT" /opt/mailcow-dockerized/data/assets/ssl/$MAILCOW_HOSTNAME/cert.pem
cp "$KEY" /opt/mailcow-dockerized/data/assets/ssl/$MAILCOW_HOSTNAME/key.pem

# --- Restart containers only *if they exist* (your request) ---
postfix_c=$(docker ps -qaf name=postfix-mailcow)
dovecot_c=$(docker ps -qaf name=dovecot-mailcow)
nginx_c=$(docker ps -qaf name=nginx-mailcow)

[[ -n "$postfix_c" ]] && docker restart "$postfix_c"
[[ -n "$dovecot_c" ]] && docker restart "$dovecot_c"
[[ -n "$nginx_c" ]] && docker restart "$nginx_c"
