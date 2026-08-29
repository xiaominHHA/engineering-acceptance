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
DEPLOY_SSH_TARGET=${DEPLOY_SSH_TARGET:-ubuntu@106.53.116.230}
DEPLOY_DIR=${DEPLOY_DIR:-/home/ubuntu/engineering-acceptance-wm7023}
NGINX_CONTAINER=${NGINX_CONTAINER:-campus-nginx}
NGINX_CONF_PATH=${NGINX_CONF_PATH:-/home/ubuntu/dsl_campus/docker/nginx/nginx.conf}
DEPLOY_GIT_SSH_KEY=${DEPLOY_GIT_SSH_KEY:-/home/ubuntu/.ssh/engineering_acceptance_deploy}
REPOSITORY_URL=$(git -C "$ROOT_DIR" remote get-url origin)
required=(PRODUCTION_ENV_FILE)
missing=()
for variable in "${required[@]}"; do
  [[ -n "${!variable:-}" ]] || missing+=("$variable")
done
if ((${#missing[@]})); then
  printf 'Deployment refused; server configuration is not confirmed. Missing: %s\n' "${missing[*]}" >&2
  exit 2
fi
ssh "$DEPLOY_SSH_TARGET" bash -s -- "$tag" "$DEPLOY_DIR" "$PRODUCTION_ENV_FILE" \
  "$NGINX_CONTAINER" "$NGINX_CONF_PATH" "$REPOSITORY_URL" "$DEPLOY_GIT_SSH_KEY" <<'REMOTE'
set -Eeuo pipefail
tag=$1
deploy_dir=$2
env_file=$3
nginx_container=$4
nginx_conf=$5
repository_url=$6
git_ssh_key=$7
[[ -f "$git_ssh_key" ]] || { echo "server deploy key not found: $git_ssh_key" >&2; exit 2; }
export GIT_SSH_COMMAND="ssh -i $git_ssh_key -o IdentitiesOnly=yes"
if [[ ! -d "$deploy_dir/.git" ]]; then
  if [[ -e "$deploy_dir" ]] && [[ -n "$(find "$deploy_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "deployment directory exists but is not an empty Git checkout: $deploy_dir" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$deploy_dir")"
  git clone "$repository_url" "$deploy_dir"
fi
cd "$deploy_dir"
[[ -f "$env_file" ]] || { echo "remote production env file not found: $env_file" >&2; exit 2; }
env_mode=$(stat -c '%a' "$env_file")
[[ "$env_mode" == 600 ]] || { echo "remote production env file must have mode 600" >&2; exit 2; }
git fetch --tags origin
git checkout --detach "$tag"
jar_path="backend/target/engineering-acceptance-backend-0.0.1-SNAPSHOT.jar"
if [[ ! -f "$jar_path" ]]; then
  docker run --rm -v "$deploy_dir:/workspace" -w /workspace/backend \
    eclipse-temurin:21-jdk ./mvnw -q -DskipTests package
fi
docker network inspect wm7023-edge >/dev/null 2>&1 || docker network create wm7023-edge >/dev/null
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml build
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml up -d
backend_port=$(awk -F= '$1 == "BACKEND_HOST_PORT" {print $2}' "$env_file")
for attempt in $(seq 1 60); do
  if curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null; then
    break
  fi
  [[ "$attempt" -lt 60 ]] && sleep 2
done
curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null

if ! docker network inspect wm7023-edge --format '{{json .Containers}}' | grep -q '"Name":"'"$nginx_container"'"'; then
  docker network connect wm7023-edge "$nginx_container"
fi

rendered=$(mktemp)
updated=$(mktemp)
backup="${nginx_conf}.bak.${tag//[^A-Za-z0-9_.-]/_}.$(date +%Y%m%d%H%M%S)"
trap 'rm -f "$rendered" "$updated"' EXIT
{
  echo '# BEGIN engineering-acceptance wm7023 block'
  sed -n '1,$p' infra/nginx/backend.conf.template
  echo '# END engineering-acceptance wm7023 block'
} >"$rendered"
cp -p "$nginx_conf" "$backup"
awk -v payload="$rendered" '
  BEGIN { in_http = 0; depth = 0; inserted = 0; skipping = 0 }
  /^[[:space:]]*http[[:space:]]*\{/ { in_http = 1 }
  /^[[:space:]]*# BEGIN engineering-acceptance wm7023 block[[:space:]]*$/ { skipping = 1; next }
  skipping && /^[[:space:]]*# END engineering-acceptance wm7023 block[[:space:]]*$/ { skipping = 0; next }
  {
    if (skipping) next
    opens = gsub(/\{/, "&")
    closes = gsub(/\}/, "&")
    if (in_http && !inserted && depth == 1 && closes > 0) {
      while ((getline line < payload) > 0) print line
      close(payload)
      inserted = 1
    }
    print
    depth += opens - closes
  }
  END { if (!inserted) exit 42 }
' "$nginx_conf" >"$updated"
mv "$updated" "$nginx_conf"
if ! docker exec "$nginx_container" nginx -t; then
  cp -p "$backup" "$nginx_conf"
  echo 'nginx -t failed; restored the previous shared configuration' >&2
  exit 1
fi
docker exec "$nginx_container" nginx -s reload
REMOTE
