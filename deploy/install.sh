#!/bin/bash
# FIREBAT: code already at /opt/audio_guide (git clone / rsync).
# Does not touch food-* or reverse-ovh. Restarts only audio-guide.
set -euo pipefail

APP=/opt/audio_guide
PY="${PYTHON312:-/home/solovyshka/.local/bin/python3.12}"

install -d -m 755 "$APP"
chown -R solovyshka:solovyshka "$APP"

install -d -m 700 /opt/secrets/audio_guide
if [ ! -f /opt/secrets/audio_guide/.env ]; then
  KEY="$(openssl rand -hex 16)"
  cat > /opt/secrets/audio_guide/.env <<EOF
ADMIN_API_KEY=${KEY}
CONTENT_DIR=/opt/audio_guide/content
PUBLIC_BASE_URL=https://audio.solovyshka.com
HOST=127.0.0.1
PORT=8090
DATABASE_URL=
EOF
  chmod 600 /opt/secrets/audio_guide/.env
fi
ln -sfn /opt/secrets/audio_guide/.env "$APP/server/.env"

sudo -u solovyshka "$PY" -m venv "$APP/server/.venv"
sudo -u solovyshka "$APP/server/.venv/bin/pip" install -q -U pip
sudo -u solovyshka "$APP/server/.venv/bin/pip" install -q -r "$APP/server/requirements.txt"

install -m 644 "$APP/deploy/audio-guide.service" /etc/systemd/system/audio-guide.service
systemctl daemon-reload
systemctl enable --now audio-guide.service
sleep 2
systemctl is-active audio-guide.service
curl -sS -m 5 http://127.0.0.1:8090/health
echo
curl -sS -m 5 -o /dev/null -w "guides=%{http_code}\n" http://127.0.0.1:8090/guides
curl -sS -m 5 -o /dev/null -w "media=%{http_code}\n" http://127.0.0.1:8090/media/guides/kolomna/audio/intro.wav
