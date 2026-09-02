#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
DEVICE_ID=${1:-${INTEGRATION_DEVICE_ID:-}}

if [[ -z "$DEVICE_ID" ]]; then
  echo 'usage: scripts/integration-test.sh <android-emulator-device-id>' >&2
  exit 2
fi

PROJECT="engineering-acceptance-integration-${BASHPID}-$(date +%s)"
SMOKE_IMAGE_TAG="integration-${BASHPID}-$(date +%s)"
SMOKE_BACKEND_HOST_PORT=$((22000 + BASHPID % 8000))
export SMOKE_IMAGE_TAG SMOKE_BACKEND_HOST_PORT

COMPOSE=(docker compose -p "$PROJECT"
  --env-file "$ROOT_DIR/infra/env/test.env.example"
  -f "$ROOT_DIR/infra/compose/compose.production-smoke.yml")

cleanup() {
  "${COMPOSE[@]}" down --volumes --remove-orphans
  docker image rm "engineering-acceptance-backend:$SMOKE_IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ -n "$(docker ps --filter "publish=$SMOKE_BACKEND_HOST_PORT" --format '{{.Names}}')" ]]; then
  echo "temporary integration port is already used: $SMOKE_BACKEND_HOST_PORT" >&2
  exit 2
fi

"${COMPOSE[@]}" config >/dev/null
"${COMPOSE[@]}" up -d --build

for attempt in $(seq 1 60); do
  if curl --fail --silent \
    "http://127.0.0.1:$SMOKE_BACKEND_HOST_PORT/actuator/health" >/dev/null; then
    break
  fi
  if [[ "$attempt" == 60 ]]; then
    echo 'integration backend did not become healthy' >&2
    exit 1
  fi
  sleep 2
done

(
  cd "$ROOT_DIR/frontend"
  flutter test integration_test/app_test.dart \
    -d "$DEVICE_ID" \
    --dart-define="API_BASE_URL=http://10.0.2.2:$SMOKE_BACKEND_HOST_PORT"
)
