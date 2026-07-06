#!/usr/bin/env bash
#
# One-time Cloudflare Tunnel provisioning for clementcolin.com.
#
# Run this once on the machine that will hold the tunnel credentials (the Mint
# VM for testing, or the Chromebook). It logs in to Cloudflare, creates a named
# tunnel, drops the credentials and a generated config.yml into ./cloudflared
# (gitignored), and points DNS at the tunnel. When it finishes, go live with:
#
#     make deploy        (or: docker compose --profile tunnel up -d)
#
# The tunnel itself runs in Docker, so cloudflared only needs to be installed
# for this one-time setup, not to keep the site running.

set -euo pipefail

TUNNEL_NAME="portfolio"
DOMAIN="clementcolin.com"
CF_DIR="./cloudflared"

# --- cloudflared must be present for the one-time setup ------------------------
if ! command -v cloudflared >/dev/null 2>&1; then
  ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  cat >&2 <<EOF

  ----------------------------------------------------------------------
  Nothing is wrong. You just need cloudflared installed first.

  It is needed once, on this machine, to create the tunnel. Running the
  tunnel later happens inside Docker, so you will not need it after that.

  Paste these two commands, then run 'make tunnel-setup' again:

    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb -o /tmp/cloudflared.deb
    sudo dpkg -i /tmp/cloudflared.deb
  ----------------------------------------------------------------------

EOF
  exit 1
fi

mkdir -p "$CF_DIR"

# --- log in, only if not already logged in ------------------------------------
# cloudflared stores an account cert at ~/.cloudflared/cert.pem after login and
# refuses to overwrite it, so skip the step entirely when it is already there.
if [ -f "$HOME/.cloudflared/cert.pem" ]; then
  echo "==> Already logged in to Cloudflare, skipping browser login."
else
  echo "==> Logging in to Cloudflare (a browser window will open)..."
  cloudflared tunnel login
fi

# --- create the tunnel, or reuse it if it already exists -----------------------
if cloudflared tunnel list | awk '{print $2}' | grep -qx "$TUNNEL_NAME"; then
  echo "==> Tunnel '$TUNNEL_NAME' already exists, reusing it."
else
  echo "==> Creating tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel create "$TUNNEL_NAME"
fi

TUNNEL_ID="$(cloudflared tunnel list | awk -v n="$TUNNEL_NAME" '$2==n {print $1}')"
CRED_SRC="$HOME/.cloudflared/${TUNNEL_ID}.json"

if [ ! -f "$CRED_SRC" ]; then
  echo "Credentials file $CRED_SRC not found on this machine." >&2
  exit 1
fi

# --- stage credentials + config for the container to mount ---------------------
# Only the tunnel credentials are copied in. The account cert stays in
# ~/.cloudflared and never touches the runtime mount.
cp "$CRED_SRC" "$CF_DIR/${TUNNEL_ID}.json"
# cloudflared creates the credential as 0600 (owner only), but the container
# runs as a non-root user and reads it through the mount, so it must be
# world-readable. The file is gitignored and stays on this host.
chmod 644 "$CF_DIR/${TUNNEL_ID}.json"

# credentials-file uses the container path, since the cloudflared container is
# what runs the tunnel (./cloudflared is mounted to /etc/cloudflared).
cat > "$CF_DIR/config.yml" <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: /etc/cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${DOMAIN}
    service: http://web:80
  - hostname: www.${DOMAIN}
    service: http://web:80
  - service: http_status:404
EOF
echo "==> Wrote $CF_DIR/config.yml"

# --- point DNS at the tunnel (creates the CNAME records for you) ---------------
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" \
  || echo "   (DNS for $DOMAIN may already be set, continuing)"
cloudflared tunnel route dns "$TUNNEL_NAME" "www.$DOMAIN" \
  || echo "   (DNS for www.$DOMAIN may already be set, continuing)"

echo
echo "Done. Bring the site online with:  make deploy"
