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
required=(PRODUCTION_ENV_FILE TLS_CERT_PATH TLS_KEY_PATH)
missing=()
for variable in "${required[@]}"; do
  [[ -n "${!variable:-}" ]] || missing+=("$variable")
done
if ((${#missing[@]})); then
  printf 'Deployment refused; server configuration is not confirmed. Missing: %s\n' "${missing[*]}" >&2
  exit 2
fi
[[ -f "$PRODUCTION_ENV_FILE" ]] || { echo "production env file not found: $PRODUCTION_ENV_FILE" >&2; exit 2; }

ssh "$DEPLOY_SSH_TARGET" bash -s -- "$tag" "$DEPLOY_DIR" "$PRODUCTION_ENV_FILE" \
  "$NGINX_CONTAINER" "$NGINX_CONF_PATH" "$TLS_CERT_PATH" "$TLS_KEY_PATH" <<'REMOTE'
set -Eeuo pipefail
tag=$1
deploy_dir=$2
env_file=$3
nginx_container=$4
nginx_conf=$5
tls_cert_path=$6
tls_key_path=$7
cd "$deploy_dir"
git fetch --tags origin
git checkout --detach "$tag"
docker network inspect wm7023-edge >/dev/null 2>&1 || docker network create wm7023-edge >/dev/null
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml build
docker compose --env-file "$env_file" -p engineering-acceptance-production \
  -f infra/compose/compose.production.yml up -d
backend_port=$(awk -F= '$1 == "BACKEND_HOST_PORT" {print $2}' "$env_file")
curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null

if ! docker network inspect wm7023-edge --format '{{json .Containers}}' | grep -q '"Name":"'"$nginx_container"'"'; then
  docker network connect wm7023-edge "$nginx_container"
fi

rendered=$(mktemp)
updated=$(mktemp)
backup="${nginx_conf}.bak.${tag//[^A-Za-z0-9_.-]/_}.$(date +%Y%m%d%H%M%S)"
trap 'rm -f "$rendered" "$updated"' EXIT
sed -e "s|\${TLS_CERT_PATH}|$tls_cert_path|g" \
    -e "s|\${TLS_KEY_PATH}|$tls_key_path|g" \
    infra/nginx/backend.conf.template >"$rendered"
cp -p "$nginx_conf" "$backup"
awk -v payload="$rendered" '
  BEGIN { in_http = 0; depth = 0; inserted = 0 }
  /^[[:space:]]*http[[:space:]]*\{/ { in_http = 1 }
  {
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
