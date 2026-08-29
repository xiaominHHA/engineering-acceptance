#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
DIST_DIR="$ROOT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/frontend" "$DIST_DIR/backend"
(cd "$ROOT_DIR/frontend" && flutter build apk --release --target-platform android-arm64)
(cd "$ROOT_DIR/backend" && ./mvnw -q package -DskipTests)
cp "$ROOT_DIR/frontend/build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/frontend/app-release.apk"
jar_file=$(find "$ROOT_DIR/backend/target" -maxdepth 1 -type f -name '*.jar' ! -name '*.original' | head -n 1)
test -n "$jar_file"
cp "$jar_file" "$DIST_DIR/backend/$(basename "$jar_file")"
