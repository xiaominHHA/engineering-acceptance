#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
if [[ $# -ne 1 || "$1" == latest || ! "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo 'usage: ./deploy.sh <explicit-release-tag>' >&2
  exit 2
fi
tag=$1
git -C "$ROOT_DIR" diff --quiet || { echo 'working tree has unstaged changes' >&2; exit 2; }
git -C "$ROOT_DIR" diff --cached --quiet || { echo 'working tree has staged changes' >&2; exit 2; }
git -C "$ROOT_DIR" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null || {
  echo "release tag does not exist locally: $tag" >&2
  exit 2
}
required=(DEPLOY_SSH_TARGET DEPLOY_DIR PRODUCTION_ENV_FILE)
missing=()
for variable in "${required[@]}"; do
  [[ -n "${!variable:-}" ]] || missing+=("$variable")
done
if ((${#missing[@]})); then
  printf 'Deployment refused; server configuration is not confirmed. Missing: %s\n' "${missing[*]}" >&2
  exit 2
fi
[[ -f "$PRODUCTION_ENV_FILE" ]] || { echo "production env file not found: $PRODUCTION_ENV_FILE" >&2; exit 2; }

ssh "$DEPLOY_SSH_TARGET" bash -s -- "$tag" "$DEPLOY_DIR" "$PRODUCTION_ENV_FILE" <<'REMOTE'
set -Eeuo pipefail
tag=$1
deploy_dir=$2
env_file=$3
cd "$deploy_dir"
git fetch --tags origin
git checkout --detach "$tag"
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml build
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml up -d
backend_port=$(awk -F= '$1 == "BACKEND_HOST_PORT" {print $2}' "$env_file")
curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null
REMOTE
