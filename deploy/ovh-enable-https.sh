#!/bin/bash
# OVH: certificate + SNI split on :443 (HTTPS vs Telegram mtg).
# Run on OVH after audio.solovyshka.com is a grey A to 51.254.219.211.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DOMAIN=audio.solovyshka.com

if ! getent hosts "$DOMAIN" | grep -q '51.254.219.211'; then
  echo "$DOMAIN does not resolve to 51.254.219.211 yet" >&2
  getent hosts "$DOMAIN" || true
  exit 1
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y certbot
sudo mkdir -p /var/www/letsencrypt/.well-known/acme-challenge /etc/nginx/stream.d
sudo certbot certonly --webroot -w /var/www/letsencrypt -d "$DOMAIN" \
  --agree-tos --register-unsafely-without-email --non-interactive --keep-until-expiring

sudo install -m 644 "$ROOT/ovh-nginx-stream.conf" /etc/nginx/stream.d/audio-guide.conf
sudo install -m 644 "$ROOT/ovh-nginx.conf" /etc/nginx/sites-enabled/audio-guide

if ! grep -q 'include /etc/nginx/stream.d/' /etc/nginx/nginx.conf; then
  sudo python3 - <<'PY'
from pathlib import Path
path = Path("/etc/nginx/nginx.conf")
text = path.read_text()
needle = "include /etc/nginx/stream.d/*.conf;"
if needle in text:
    raise SystemExit
block = "\nstream {\n\tinclude /etc/nginx/stream.d/*.conf;\n}\n"
if "stream {" in text:
    raise SystemExit("nginx.conf already has a stream block; add stream.d include by hand")
path.write_text(text.rstrip() + block)
PY
fi

# Free public :443 for the SNI splitter. Telegram stays on 443 from the outside.
sudo python3 - <<'PY'
from pathlib import Path
path = Path("/etc/mtg.toml")
text = path.read_text()
old = 'bind-to = "0.0.0.0:443"'
new = 'bind-to = "127.0.0.1:4433"'
if old not in text and new not in text:
    raise SystemExit("mtg.toml bind-to is not the expected 0.0.0.0:443")
if old in text:
    path.write_text(text.replace(old, new, 1))
PY

sudo nginx -t
sudo systemctl restart mtg
sudo systemctl reload nginx
echo "HTTPS ready: https://$DOMAIN/guides"
