#!/bin/bash
# Usage: bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide [audio-guide]
set -euo pipefail

project="${1:?project}"
app_root="${2:?app root}"
shift 2

src="/opt/secrets/${project}/.env"
if [ ! -f "$src" ]; then
  echo "missing $src" >&2
  exit 1
fi

ln -sfn "$src" "${app_root}/server/.env"

for svc in "$@"; do
  systemctl restart "$svc"
done
