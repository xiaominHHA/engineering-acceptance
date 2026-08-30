#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
PROJECT="engineering-acceptance-test-${BASHPID}-$(date +%s)"
COMPOSE=(docker compose -p "$PROJECT" --env-file "$ROOT_DIR/infra/env/test.env.example" -f "$ROOT_DIR/infra/compose/compose.test.yml")
cleanup() { "${COMPOSE[@]}" down --volumes --remove-orphans --rmi local; }
trap cleanup EXIT
"${COMPOSE[@]}" up -d mysql mongo
"${COMPOSE[@]}" run --rm backend-test test -q
(cd "$ROOT_DIR/frontend" && flutter test)
"$ROOT_DIR/scripts/production-smoke-test.sh"
