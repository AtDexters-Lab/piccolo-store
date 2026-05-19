#!/bin/sh
# Gitea init: create the bootstrap admin if no admin exists. Runs via
# `podman exec` as root after the container is started. Idempotent.
set -eu

CONFIG=/data/gitea/conf/app.ini

# Wait up to 60s for Gitea HTTP to come up.
i=0
while [ $i -lt 60 ]; do
  if wget -q -O- http://127.0.0.1:3000/api/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 1
  i=$((i + 1))
done

# Create the admin if none exists.
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
