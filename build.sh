#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
DIST_DIR="$ROOT_DIR/dist"
RELEASE_API_BASE_URL=${API_BASE_URL:-http://wm7023.campusmeow.com}
# Resolved from this script's repository root.
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release-metadata.sh"
resolve_release_metadata

signing_properties=${ANDROID_SIGNING_PROPERTIES_FILE:-$HOME/.config/engineering-acceptance/android-signing.properties}
if [[ -f "$signing_properties" ]]; then
  [[ "$(stat -c '%a' "$signing_properties")" == 600 ]] || {
    echo 'Android signing properties must have mode 600' >&2
    exit 2
  }
  export ANDROID_SIGNING_PROPERTIES_FILE=$signing_properties
else
  required_signing=(ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD)
  for name in "${required_signing[@]}"; do
    [[ -n "${!name:-}" ]] || {
      echo "release signing config is missing; set $name or create the external properties file" >&2
      exit 2
    }
  done
  [[ -f "$ANDROID_KEYSTORE_PATH" ]] || { echo 'release keystore file is missing' >&2; exit 2; }
  [[ "$(stat -c '%a' "$ANDROID_KEYSTORE_PATH")" == 600 ]] || {
    echo 'release keystore must have mode 600' >&2
    exit 2
  }
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/frontend" "$DIST_DIR/backend"
(cd "$ROOT_DIR/frontend" && flutter build apk --release --target-platform android-arm64 \
  --build-name="$ANDROID_VERSION_NAME" --build-number="$ANDROID_VERSION_CODE" \
  --dart-define="API_BASE_URL=$RELEASE_API_BASE_URL" \
  --dart-define="APP_VERSION=$PROJECT_VERSION" \
  --dart-define="GIT_COMMIT=$GIT_COMMIT")
(cd "$ROOT_DIR/backend" && ./mvnw -q package -DskipTests \
  -Drevision="$PROJECT_VERSION" -Dgit.commit="$GIT_COMMIT")
cp "$ROOT_DIR/frontend/build/app/outputs/flutter-apk/app-release.apk" \
  "$DIST_DIR/frontend/engineering-acceptance-app-$ARTIFACT_VERSION.apk"
jar_file=$(find "$ROOT_DIR/backend/target" -maxdepth 1 -type f -name '*.jar' ! -name '*.original' | head -n 1)
test -n "$jar_file"
cp "$jar_file" "$DIST_DIR/backend/$(basename "$jar_file")"
