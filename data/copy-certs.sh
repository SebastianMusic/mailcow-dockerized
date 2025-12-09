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
#!/bin/bash

MAILCOW_HOSTNAME="mx1.infra.ijo.no"
CADDY_BASE="/var/lib/caddy/.local/share/caddy/certificates"
MAILCOW_SSL="/opt/mailcow-dockerized/data/assets/ssl"

echo ""
echo "✨ Starting certificate sync: $MAILCOW_HOSTNAME"
echo "--------------------------------------------------"

# -------------------------------
# 1. Locate certificate directory
# -------------------------------
CERT_DIR=$(find "$CADDY_BASE" -type f -name "${MAILCOW_HOSTNAME}.crt" -printf '%h' | head -n 1)

if [[ -z "$CERT_DIR" ]]; then
  echo "❌ ERROR: Cannot find Caddy certificates for: $MAILCOW_HOSTNAME"
  echo "   Looked under: $CADDY_BASE"
  exit 1
fi

CRT="$CERT_DIR/$MAILCOW_HOSTNAME.crt"
KEY="$CERT_DIR/$MAILCOW_HOSTNAME.key"

echo "📁 Found certificate directory:"
echo "   $CERT_DIR"
echo ""

# -------------------------------
# 2. Compute MD5 checksums
# -------------------------------
if [[ -f "$MAILCOW_SSL/cert.pem" ]]; then
  MD5SUM_CURRENT=$(md5sum "$MAILCOW_SSL/cert.pem" | awk '{print $1}')
else
  MD5SUM_CURRENT="none"
fi

MD5SUM_NEW=$(md5sum "$CRT" | awk '{print $1}')

echo "🔍 Current MD5: $MD5SUM_CURRENT"
echo "🔍 New MD5:     $MD5SUM_NEW"

# -------------------------------
# 3. Detect no-change condition
# -------------------------------
if [[ "$MD5SUM_CURRENT" == "$MD5SUM_NEW" ]]; then
  echo "👌 Certificate unchanged — no updates needed."
  exit 0
fi

echo "🔄 Certificate changed — updating files..."
echo ""

# -------------------------------
# 4. Ensure target directories exist
# -------------------------------
mkdir -p "$MAILCOW_SSL/$MAILCOW_HOSTNAME"

# -------------------------------
# 5. Copy certificates
# -------------------------------
copy_file() {
  local src="$1"
  local dst="$2"

  if cp "$src" "$dst" 2>/dev/null; then
    echo "✔ Copied: $dst"
  else
    echo "⚠ WARN: Could not copy $src → $dst"
  fi
}

copy_file "$CRT" "$MAILCOW_SSL/cert.pem"
copy_file "$KEY" "$MAILCOW_SSL/key.pem"
copy_file "$CRT" "$MAILCOW_SSL/$MAILCOW_HOSTNAME/cert.pem"
copy_file "$KEY" "$MAILCOW_SSL/$MAILCOW_HOSTNAME/key.pem"

echo ""
echo "🔁 Checking if Mailcow containers exist..."

# -------------------------------
# 6. Restart containers if they exist
# -------------------------------
restart_if_exists() {
  local cname="$1"
  local id
  id=$(docker ps -qaf "name=$cname")

  if [[ -n "$id" ]]; then
    echo "🔁 Restarting container: $cname"
    docker restart "$id" >/dev/null 2>&1 ||
      echo "⚠ WARN: Failed restarting $cname"
  else
    echo "ℹ Container not running: $cname (skipped)"
  fi
}

restart_if_exists "postfix-mailcow"
restart_if_exists "dovecot-mailcow"
restart_if_exists "nginx-mailcow"

echo ""
echo "✅ Certificate sync completed!"
