#!/usr/bin/env bash
#
# Tear down the Cloudflare Tunnel created by tunnel-setup.sh.
#
# Stops the containers, deletes the 'portfolio' tunnel from Cloudflare, and
# removes the staged credentials and generated config from ./cloudflared.
#
# One thing it cannot do: cloudflared has no command to remove a DNS route, so
# the clementcolin.com and www CNAME records that setup created stay behind.
# Delete them in the Cloudflare dashboard, otherwise they keep pointing at a
# tunnel that no longer exists.

set -euo pipefail

TUNNEL_NAME="portfolio"
CF_DIR="./cloudflared"

# 1. Bring the stack down so the tunnel has no active connections blocking the
#    delete. This stops nginx too, so the site goes offline.
echo "==> Stopping containers..."
docker compose --profile tunnel down

# 2. Delete the tunnel from Cloudflare (needs cloudflared and a prior login).
if command -v cloudflared >/dev/null 2>&1 \
   && cloudflared tunnel list | awk '{print $2}' | grep -qx "$TUNNEL_NAME"; then
  echo "==> Deleting tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel cleanup "$TUNNEL_NAME" || true
  cloudflared tunnel delete "$TUNNEL_NAME"
else
  echo "==> No tunnel '$TUNNEL_NAME' found to delete (or cloudflared not installed)."
fi

# 3. Remove staged credentials and generated config.
echo "==> Removing staged credentials and config..."
rm -f "$CF_DIR"/*.json "$CF_DIR"/config.yml

echo
echo "Done. Remember to delete the clementcolin.com and www CNAME records in the"
echo "Cloudflare dashboard, cloudflared cannot remove DNS routes itself."
