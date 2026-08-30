#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
cd "$ROOT_DIR"
command -v flutter >/dev/null
command -v dart >/dev/null
run_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$@"
  else
    docker run --rm -v "$ROOT_DIR:/mnt:ro" koalaman/shellcheck:v0.10.0 \
      "${@/#$ROOT_DIR/\/mnt}"
  fi
}
(cd frontend && dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-warnings --fatal-infos)
(cd backend && ./mvnw -q checkstyle:check -Dcheckstyle.config.location="$ROOT_DIR/config/checkstyle/checkstyle.xml")
mapfile -d '' root_scripts < <(find "$ROOT_DIR" -maxdepth 1 -type f -name '*.sh' -print0)
mapfile -d '' helper_scripts < <(find "$ROOT_DIR/scripts" -type f -name '*.sh' -print0)
if ((${#root_scripts[@]})); then run_shellcheck "${root_scripts[@]}"; fi
if ((${#helper_scripts[@]})); then run_shellcheck "${helper_scripts[@]}"; fi
docker compose -f infra/compose/compose.local.yml config >/dev/null
docker compose -f infra/compose/compose.test.yml config >/dev/null
env SMOKE_IMAGE_TAG=lint-smoke SMOKE_BACKEND_HOST_PORT=18082 \
  docker compose --env-file infra/env/test.env.example \
  -f infra/compose/compose.production-smoke.yml config >/dev/null
env BACKEND_HOST_PORT=18081 MYSQL_HOST_PORT=13307 MONGO_HOST_PORT=17018 \
  BACKEND_MEMORY_LIMIT=512m MYSQL_MEMORY_LIMIT=512m MONGO_MEMORY_LIMIT=512m \
  RELEASE_IMAGE_TAG=v0.0.0 \
  MYSQL_DATABASE=acceptance MYSQL_USER=acceptance MYSQL_PASSWORD=lint_password \
  MYSQL_ROOT_PASSWORD=lint_root_password MONGO_DATABASE=acceptance \
  MONGO_INITDB_ROOT_USERNAME=lint_admin MONGO_INITDB_ROOT_PASSWORD=lint_mongo_password \
  SPRING_PROFILES_ACTIVE=production docker compose -f infra/compose/compose.production.yml config >/dev/null
scripts/check-file-length.sh
scripts/check-secrets.sh
