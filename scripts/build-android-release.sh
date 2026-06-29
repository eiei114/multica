#!/usr/bin/env bash
set -euo pipefail

# Build the private fork Android release APK on Linux CI.
# Local Windows development still uses scripts/build-android-debug.ps1.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_ENV="${APP_ENV:-production}"
ARCHITECTURE="${REACT_NATIVE_ARCHITECTURES:-arm64-v8a}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
GRADLE_TASK="assemble${BUILD_TYPE}"

echo "Repo: $REPO_ROOT"
echo "APP_ENV: $APP_ENV"
echo "Build type: $BUILD_TYPE"
echo "Architecture: $ARCHITECTURE"

pnpm install --ignore-scripts

pushd apps/mobile >/dev/null
APP_ENV="$APP_ENV" pnpm exec expo prebuild --platform android
popd >/dev/null

python - <<'PY'
from pathlib import Path

wrapper = Path("apps/mobile/android/gradle/wrapper/gradle-wrapper.properties")
text = wrapper.read_text()
import re
patched = re.sub(r"gradle-[0-9.]+-bin\.zip", "gradle-8.14.3-bin.zip", text)
wrapper.write_text(patched)
print("Pinned Gradle wrapper to 8.14.3")
PY

if [[ "$BUILD_TYPE" == "Release" && -n "${ANDROID_KEYSTORE_PATH:-}" ]]; then
  python - <<'PY'
import os
from pathlib import Path

for name in ["ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]:
    if not os.environ.get(name):
        raise SystemExit(f"{name} is required for release signing")

build_gradle = Path("apps/mobile/android/app/build.gradle")
text = build_gradle.read_text()

if "def keystorePath = System.getenv(\"ANDROID_KEYSTORE_PATH\")" not in text:
    release_signing = '''    release {
        def keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
        if (keystorePath == null || keystorePath.length() == 0) {
            throw new GradleException("ANDROID_KEYSTORE_PATH is required for release signing")
        }
        storeFile file(keystorePath)
        storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
        keyAlias System.getenv("ANDROID_KEY_ALIAS")
        keyPassword System.getenv("ANDROID_KEY_PASSWORD")
    }
'''
    text = text.replace("signingConfigs {\n", "signingConfigs {\n" + release_signing, 1)

needle = "            signingConfig signingConfigs.debug"
first = text.find(needle)
second = text.find(needle, first + len(needle)) if first >= 0 else -1
if second < 0:
    raise SystemExit("Could not find generated release signingConfig line")
text = text[:second] + "            signingConfig signingConfigs.release" + text[second + len(needle):]

build_gradle.write_text(text)
print("Configured Android release signing from ANDROID_KEYSTORE_PATH")
PY
elif [[ "$BUILD_TYPE" == "Release" ]]; then
  echo "ANDROID_KEYSTORE_PATH is not set; generated release signing config will be used."
fi

pushd apps/mobile/android >/dev/null
chmod +x ./gradlew
./gradlew "$GRADLE_TASK" "-PreactNativeArchitectures=$ARCHITECTURE" --no-daemon --stacktrace
popd >/dev/null

variant_dir="$(tr '[:upper:]' '[:lower:]' <<< "$BUILD_TYPE")"
apk="apps/mobile/android/app/build/outputs/apk/${variant_dir}/app-${variant_dir}.apk"
if [[ ! -f "$apk" ]]; then
  echo "APK not found after build: $apk" >&2
  exit 1
fi

echo "Built APK: $apk"

