#!/bin/bash
# Build signed release APK on FIREBAT and publish to OVH /app/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
DEVELOP="${DEVELOP:-$HOME/develop}"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$DEVELOP/flutter}"
SECRETS="${SECRETS:-$HOME/.local/share/audio_guide}"
PUBLIC_BASE="${PUBLIC_BASE_URL:-https://audio.solovyshka.com}"
OVH_HOST="${OVH_HOST:-ubuntu@51.254.219.211}"
VDS_HOST="${VDS_HOST:-root@135.106.218.22}"

export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export PATH="$FLUTTER_ROOT/bin:$JAVA_HOME/bin:$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:$PATH"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Flutter not found. Run: bash $ROOT/deploy/install-android-toolchain.sh" >&2
  exit 1
fi

install -d -m 700 "$SECRETS"
if [ ! -f "$SECRETS/upload.jks" ]; then
  STORE_PASSWORD="$(openssl rand -hex 16)"
  keytool -genkeypair -noprompt \
    -keystore "$SECRETS/upload.jks" \
    -storetype JKS \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias upload \
    -storepass "$STORE_PASSWORD" \
    -keypass "$STORE_PASSWORD" \
    -dname "CN=audio_guide, OU=solovyshka, O=solovyshka, C=RU"
  chmod 640 "$SECRETS/upload.jks"
  cat > "$SECRETS/keystore.env" <<EOF
STORE_FILE=$SECRETS/upload.jks
STORE_PASSWORD=$STORE_PASSWORD
KEY_ALIAS=upload
KEY_PASSWORD=$STORE_PASSWORD
EOF
  chmod 600 "$SECRETS/keystore.env"
  chgrp solovyshka "$SECRETS/upload.jks" "$SECRETS/keystore.env" 2>/dev/null || true
  if [ -d /opt/secrets/audio_guide ]; then
    sudo cp -a "$SECRETS/upload.jks" "$SECRETS/keystore.env" /opt/secrets/audio_guide/ || true
  fi
fi

# shellcheck disable=SC1091
set -a
. "$SECRETS/keystore.env"
set +a

cat > "$APP/android/key.properties" <<EOF
storeFile=$STORE_FILE
storePassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
EOF
chmod 600 "$APP/android/key.properties"

cd "$APP"
if [ ! -f lib/secrets.dart ]; then
  cp lib/secrets.example.dart lib/secrets.dart
fi

DEFINE_ARGS=()
if [ -f "$SECRETS/mapkit.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SECRETS/mapkit.env"
  set +a
fi
if [ -n "${MAPKIT_API_KEY:-}" ]; then
  python3 - "$SECRETS/dart-defines.json" <<'PY'
import json, os, sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(json.dumps({"MAPKIT_API_KEY": os.environ["MAPKIT_API_KEY"]}) + "\n")
path.chmod(0o600)
PY
  DEFINE_ARGS+=(--dart-define-from-file="$SECRETS/dart-defines.json")
fi

flutter pub get
flutter build apk --release --no-tree-shake-icons --split-per-abi "${DEFINE_ARGS[@]}"

APK="$ROOT/audio_guide.apk"
ARM64="$APP/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "$ARM64" ]; then
  echo "arm64 APK not found: $ARM64" >&2
  exit 1
fi
cp -f "$ARM64" "$APK"
cp -f "$ARM64" "$ROOT/audio_guide-arm64-v8a-release.apk"
for abi in armeabi-v7a x86_64; do
  split="$APP/build/app/outputs/flutter-apk/app-${abi}-release.apk"
  if [ -f "$split" ]; then
    cp -f "$split" "$ROOT/audio_guide-${abi}-release.apk"
  fi
done

# Split ABI APKs get versionCode = abiCode*1000 + pubspec plus
# (arm64-v8a → 2xxx). The phone compares PackageInfo.buildNumber
# to version.json, so publish the code aapt writes into the APK.
AAPT="$(ls -1 "$ANDROID_SDK"/build-tools/*/aapt 2>/dev/null | sort | tail -1)"
if [ -z "$AAPT" ] || [ ! -x "$AAPT" ]; then
  echo "aapt not found under $ANDROID_SDK/build-tools" >&2
  exit 1
fi
VERSION_LINE="$(python3 - "$APK" "$AAPT" <<'PY'
import re, subprocess, sys
apk, aapt = sys.argv[1], sys.argv[2]
text = subprocess.check_output([aapt, "dump", "badging", apk], text=True)
code = re.search(r"versionCode='(\d+)'", text)
name = re.search(r"versionName='([^']+)'", text)
if not code or not name:
    raise SystemExit("aapt did not report versionCode/versionName")
print(name.group(1), code.group(1))
PY
)"
VERSION_NAME="${VERSION_LINE%% *}"
VERSION_CODE="${VERSION_LINE##* }"
SIZE="$(stat -c%s "$APK")"

python3 - <<PY
import json
from pathlib import Path
Path("$ROOT/app/build/version.json").parent.mkdir(parents=True, exist_ok=True)
Path("$ROOT/deploy/out").mkdir(parents=True, exist_ok=True)
payload = {
    "versionCode": int("$VERSION_CODE"),
    "versionName": "$VERSION_NAME",
    "apkUrl": "$PUBLIC_BASE/app/update.bin",
    "sizeBytes": int("$SIZE"),
}
text = json.dumps(payload, indent=2) + "\n"
Path("$ROOT/deploy/out/version.json").write_text(text)
print(text)
PY

if [ "${SKIP_PUBLISH:-0}" = "1" ]; then
  echo "Built $VERSION_NAME+$VERSION_CODE (SKIP_PUBLISH=1) -> $APK"
  exit 0
fi

if scp -o BatchMode=yes -o ConnectTimeout=20 "$APK" "$ROOT/deploy/out/version.json" "$ROOT/deploy/app-index.html" "$OVH_HOST:/tmp/"; then
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$OVH_HOST" 'sudo install -d -m 755 /var/www/audio-guide-app
sudo install -m 644 /tmp/audio_guide.apk /var/www/audio-guide-app/audio_guide.apk
sudo ln -sfn audio_guide.apk /var/www/audio-guide-app/update.bin
sudo install -m 644 /tmp/version.json /var/www/audio-guide-app/version.json
sudo install -m 644 /tmp/app-index.html /var/www/audio-guide-app/index.html
rm -f /tmp/audio_guide.apk /tmp/version.json /tmp/app-index.html
curl -sS -m 10 -o /dev/null -w "version=%{http_code}\n" http://127.0.0.1/app/version.json
curl -sS -m 10 -o /dev/null -w "page=%{http_code}\n" http://127.0.0.1/app/
curl -sS -m 10 -o /dev/null -w "update=%{http_code} size=%{size_download}\n" http://127.0.0.1/app/update.bin
'
else
  echo "OVH publish skipped: $OVH_HOST unreachable" >&2
fi

scp -o BatchMode=yes -o ConnectTimeout=20 "$APK" "$ROOT/deploy/out/version.json" "$ROOT/deploy/app-index.html" "$VDS_HOST:/tmp/"
ssh -o BatchMode=yes -o ConnectTimeout=20 "$VDS_HOST" 'sudo install -d -m 755 /var/www/audio-guide-app
sudo install -m 644 /tmp/audio_guide.apk /var/www/audio-guide-app/audio_guide.apk
sudo ln -sfn audio_guide.apk /var/www/audio-guide-app/update.bin
sudo install -m 644 /tmp/version.json /var/www/audio-guide-app/version.json
sudo install -m 644 /tmp/app-index.html /var/www/audio-guide-app/index.html
rm -f /tmp/audio_guide.apk /tmp/version.json /tmp/app-index.html
'

echo "Published $VERSION_NAME+$VERSION_CODE -> $PUBLIC_BASE/app/ and VDS /audio/app/"
