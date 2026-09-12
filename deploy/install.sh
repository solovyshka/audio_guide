#!/bin/bash
set -euo pipefail

install -d /opt/audio_guide
tar -xf /tmp/audio_guide_deploy.tar -C /opt/audio_guide
rm -f /tmp/audio_guide_deploy.tar

cd /opt/audio_guide/server
python3 -m venv .venv
.venv/bin/pip install -q -U pip
.venv/bin/pip install -q -r requirements.txt

install -d -m 700 /opt/secrets/audio_guide
if [ ! -f /opt/secrets/audio_guide/.env ]; then
  KEY="$(openssl rand -hex 16)"
  cat > /opt/secrets/audio_guide/.env <<EOF
ADMIN_API_KEY=${KEY}
CONTENT_DIR=/opt/audio_guide/content
PUBLIC_BASE_URL=http://161.104.53.72
HOST=127.0.0.1
PORT=8090
DATABASE_URL=
EOF
  chmod 600 /opt/secrets/audio_guide/.env
fi
ln -sfn /opt/secrets/audio_guide/.env /opt/audio_guide/server/.env

cat > /etc/systemd/system/audio-guide.service <<'UNIT'
[Unit]
Description=Audio Guide API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/audio_guide/server
EnvironmentFile=/opt/secrets/audio_guide/.env
ExecStart=/opt/audio_guide/server/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8090
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

cp -a /etc/nginx/sites-enabled/food-reports /etc/nginx/sites-enabled/food-reports.bak.audio-guide
cat > /etc/nginx/sites-enabled/food-reports <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location /r/ {
        alias /opt/food_checking/var/reports/;
        default_type text/html;
        charset utf-8;
        autoindex off;
        add_header X-Content-Type-Options nosniff;
        add_header Cache-Control "private, max-age=300";
    }

    location /media/ {
        alias /opt/audio_guide/content/;
        autoindex off;
        add_header Accept-Ranges bytes;
    }

    location /guides {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location = /health {
        proxy_pass http://127.0.0.1:8090/health;
    }

    location = / {
        return 204;
    }

    location / {
        return 404;
    }
}
NGINX

nginx -t
systemctl daemon-reload
systemctl enable --now audio-guide.service
systemctl reload nginx
sleep 1
systemctl is-active audio-guide.service
curl -sS http://127.0.0.1:8090/health
echo
curl -sS "http://127.0.0.1/guides/search?q=коломна" | head -c 400
echo
curl -sS -o /dev/null -w "media=%{http_code}\n" http://127.0.0.1/media/guides/kolomna/audio/intro.wav
