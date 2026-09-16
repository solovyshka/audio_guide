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

umask 077
tmp="$(mktemp)"
python3 - "$src" "$tmp" <<'PY'
import sys
from pathlib import Path

wanted = {
    "OPENAI_API_KEY",
    "OPENAI_MODEL",
    "OPENAI_QA_MODEL",
    "OPENAI_TIMEOUT",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "HIDEME_OVPN_CONF",
}
src = Path(sys.argv[1])
out = Path(sys.argv[2])
values: dict[str, str] = {}
candidates = [src, Path("/opt/secrets/food_checking/.env")]
for path in candidates:
    if not path.is_file():
        continue
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key in wanted and key not in values and value.strip():
            values[key] = line
out.write_text("".join(f"{line}\n" for line in values.values()))
PY
install -m 600 -o solovyshka -g solovyshka "$tmp" "${app_root}/generate/.env"
rm -f "$tmp"

for svc in "$@"; do
  systemctl restart "$svc"
done
