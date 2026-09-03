#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
DIST_DIR="$ROOT_DIR/dist"
RELEASE_API_BASE_URL=${API_BASE_URL:-http://wm7023.campusmeow.com}
WEB_API_BASE_URL=${WEB_API_BASE_URL:-}
ANDROID_BUILD_TYPE=${ANDROID_BUILD_TYPE:-release}
# Resolved from this script's repository root.
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release-metadata.sh"
resolve_release_metadata

case "$ANDROID_BUILD_TYPE" in
  release)
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
    flutter_build=(flutter build apk --release --target-platform android-arm64)
    flutter_apk="$ROOT_DIR/frontend/build/app/outputs/flutter-apk/app-release.apk"
    apk_name="engineering-acceptance-app-$ARTIFACT_VERSION.apk"
    ;;
  debug)
    flutter_build=(flutter build apk --debug --target-platform android-arm64)
    flutter_apk="$ROOT_DIR/frontend/build/app/outputs/flutter-apk/app-debug.apk"
    apk_name="engineering-acceptance-app-$ARTIFACT_VERSION-debug.apk"
    ;;
  *)
    echo 'ANDROID_BUILD_TYPE must be release or debug' >&2
    exit 2
    ;;
esac

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/frontend" "$DIST_DIR/backend"
(cd "$ROOT_DIR/frontend" && "${flutter_build[@]}" \
  --build-name="$ANDROID_VERSION_NAME" --build-number="$ANDROID_VERSION_CODE" \
  --dart-define="API_BASE_URL=$RELEASE_API_BASE_URL" \
  --dart-define="APP_VERSION=$PROJECT_VERSION" \
  --dart-define="GIT_COMMIT=$GIT_COMMIT")
web_defines=(
  --dart-define="APP_VERSION=$PROJECT_VERSION"
  --dart-define="GIT_COMMIT=$GIT_COMMIT"
)
if [[ -n "$WEB_API_BASE_URL" ]]; then
  web_defines+=(--dart-define="API_BASE_URL=$WEB_API_BASE_URL")
fi
(cd "$ROOT_DIR/frontend" && flutter build web --release "${web_defines[@]}")
(cd "$ROOT_DIR/backend" && ./mvnw -q clean package -DskipTests \
  -Drevision="$PROJECT_VERSION" -Dgit.commit="$GIT_COMMIT")
cp "$flutter_apk" "$DIST_DIR/frontend/$apk_name"
web_artifact="$DIST_DIR/frontend/engineering-acceptance-web-$ARTIFACT_VERSION"
mkdir -p "$web_artifact"
cp -a "$ROOT_DIR/frontend/build/web/." "$web_artifact/"
jar_file="$ROOT_DIR/backend/target/engineering-acceptance-backend-$PROJECT_VERSION.jar"
test -s "$jar_file"
cp "$jar_file" "$DIST_DIR/backend/$(basename "$jar_file")"
