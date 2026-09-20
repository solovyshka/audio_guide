#!/usr/bin/env bash
# New city on FIREBAT: dossier + short/long guides + Silero TTS in one pass.
# Usage: bash /opt/audio_guide/deploy/new-city.sh "Сергиев Посад"
# Optional second arg short|long rebuilds only that guide.
set -euo pipefail

APP="$(cd "$(dirname "$0")/.." && pwd)"
PY="${APP}/generate/.venv/bin/python"
VPN="${APP}/deploy/vpn/hideme-openai.sh"

if [ "$#" -lt 1 ]; then
  echo "Usage: bash $0 \"Город\" [short|long]" >&2
  exit 1
fi

if [ ! -x "$PY" ]; then
  echo "No TTS/OpenAI venv. On FIREBAT:" >&2
  echo "  uv venv --python ~/.local/bin/python3.12 ${APP}/generate/.venv" >&2
  echo "  uv pip install --python $PY -r ${APP}/generate/requirements-guide.txt -r ${APP}/generate/requirements-tts.txt" >&2
  exit 1
fi

if [ ! -r "${APP}/generate/.env" ]; then
  echo "Missing readable ${APP}/generate/.env (OPENAI_API_KEY)." >&2
  echo "Run: sudo bash ${APP}/deploy/secrets/apply-local.sh audio_guide ${APP}" >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  bash "$VPN" up
else
  sudo -n "$VPN" up
fi

cd "$APP"
if [ "${2:-}" = "short" ] || [ "${2:-}" = "long" ]; then
  "$PY" -m generate.city_guide api --length "$2" "$1"
else
  "$PY" -m generate.city_guide api "$1"
fi
