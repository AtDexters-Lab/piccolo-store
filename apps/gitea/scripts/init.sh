#!/bin/sh
# Gitea init: trust Piccolo's internal CA, create the bootstrap admin, and
# register the Piccolo OIDC provider. Runs via `podman exec` as root after the
# container is started. Idempotent on every step.
set -eu

CONFIG=/data/gitea/conf/app.ini
PICCOLO_CA=/etc/ssl/certs/piccolo-internal-ca.crt
SYSTEM_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# 1. Trust Piccolo's internal CA so Gitea's outbound OIDC calls succeed.
#    Go reads the system bundle on first TLS handshake; we append here before
#    any OIDC login attempt occurs.
if [ -f "$PICCOLO_CA" ] && ! grep -qFf "$PICCOLO_CA" "$SYSTEM_BUNDLE" 2>/dev/null; then
  cat "$PICCOLO_CA" >> "$SYSTEM_BUNDLE"
fi

# 2. Wait up to 60s for Gitea HTTP to come up.
i=0
while [ $i -lt 60 ]; do
  if wget -q -O- http://127.0.0.1:3000/api/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 1
  i=$((i + 1))
done

# 3. Create the bootstrap admin if no admin exists.
if ! su git -s /bin/sh -c "/app/gitea/gitea admin user list --admin --config '$CONFIG'" 2>/dev/null \
    | tail -n +2 | grep -q .; then
  su git -s /bin/sh -c "/app/gitea/gitea admin user create \
    --username '$ADMIN_USER' \
    --password '$ADMIN_PASSWORD' \
    --email '$ADMIN_EMAIL' \
    --admin \
    --must-change-password=false \
    --config '$CONFIG'"
fi

# 4. Register the Piccolo OIDC source if not already present.
#    --auto-discover-url fetches the issuer's well-known config once and caches
#    the endpoints in the DB. Provider name 'Piccolo' must match the OAuth2
#    callback path declared in app.yaml (/user/oauth2/Piccolo/callback).
if ! su git -s /bin/sh -c "/app/gitea/gitea admin auth list --config '$CONFIG'" 2>/dev/null \
    | awk 'NR>1 {print $2}' | grep -qx "Piccolo"; then
  su git -s /bin/sh -c "/app/gitea/gitea admin auth add-oauth \
    --name 'Piccolo' \
    --provider 'openidConnect' \
    --key '$OIDC_CLIENT_ID' \
    --secret '$OIDC_CLIENT_SECRET' \
    --auto-discover-url '$OIDC_ISSUER/.well-known/openid-configuration' \
    --scopes 'openid profile email' \
    --skip-local-2fa \
    --config '$CONFIG'"
fi
