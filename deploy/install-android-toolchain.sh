#!/bin/bash
# One-time JDK 21 + Flutter + Android SDK on FIREBAT (user solovyshka).
set -euo pipefail

DEVELOP="${DEVELOP:-$HOME/develop}"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
FLUTTER_ROOT="$DEVELOP/flutter"

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  openjdk-21-jdk-headless unzip zip curl git xz-utils ca-certificates

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$DEVELOP" "$ANDROID_SDK/cmdline-tools"
if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  git clone -b stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export PATH="$FLUTTER_ROOT/bin:$PATH"
git -C "$FLUTTER_ROOT" fetch --depth 1 origin stable
git -C "$FLUTTER_ROOT" checkout -q stable
git -C "$FLUTTER_ROOT" pull --ff-only || true

flutter config --no-analytics >/dev/null
flutter precache --android

if [ ! -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  curl -fsSL -o /tmp/android-cmdtools.zip \
    https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
  rm -rf /tmp/android-cmdline-tools
  unzip -q /tmp/android-cmdtools.zip -d /tmp
  # zip root is "cmdline-tools/"
  rm -rf "$ANDROID_SDK/cmdline-tools/latest"
  mkdir -p "$ANDROID_SDK/cmdline-tools/latest"
  mv /tmp/cmdline-tools/* "$ANDROID_SDK/cmdline-tools/latest/"
  rm -f /tmp/android-cmdtools.zip
fi

export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export PATH="$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:$PATH"

set +o pipefail
yes | sdkmanager --licenses >/dev/null || true
set -o pipefail
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;35.0.1"

set +o pipefail
yes | flutter doctor --android-licenses >/dev/null || true
set -o pipefail
flutter doctor -v
