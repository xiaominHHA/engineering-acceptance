#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)

if [[ $# -ne 1 || "$1" == latest || ! "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
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
PRODUCTION_ENV_FILE=${PRODUCTION_ENV_FILE:-/home/ubuntu/.config/engineering-acceptance/production.env}
NGINX_CONTAINER=${NGINX_CONTAINER:-campus-nginx}
NGINX_CONF_PATH=${NGINX_CONF_PATH:-/home/ubuntu/dsl_campus/docker/nginx/nginx.conf}
DEPLOY_GIT_SSH_KEY=${DEPLOY_GIT_SSH_KEY:-/home/ubuntu/.ssh/engineering_acceptance_deploy}
REPOSITORY_URL=$(git -C "$ROOT_DIR" remote get-url origin)

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
project=engineering-acceptance-production
edge_network=wm7023-edge
begin_marker='# BEGIN engineering-acceptance wm7023 block'
end_marker='# END engineering-acceptance wm7023 block'

env_value() {
  local key=$1
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit}' "$env_file"
}

assert_expected_setting() {
  local key=$1 expected=$2 actual
  actual=$(env_value "$key")
  [[ "$actual" == "$expected" ]] || {
    echo "production setting $key must equal the server-approved value $expected" >&2
    exit 2
  }
}

assert_port_available() {
  local port=$1 owner
  while IFS= read -r owner; do
    [[ -z "$owner" || "$owner" == "$project-"* ]] || {
      echo "host port $port is owned by another container: $owner" >&2
      exit 2
    }
  done < <(docker ps --filter "publish=$port" --format '{{.Names}}')
}

assert_edge_members() {
  local member
  docker network inspect "$edge_network" >/dev/null 2>&1 || return 0
  while IFS= read -r member; do
    [[ -z "$member" || "$member" == "$nginx_container" || "$member" == "$project-backend-"* ]] || {
      echo "unexpected container on $edge_network: $member" >&2
      exit 2
    }
  done < <(docker network inspect "$edge_network" --format '{{range .Containers}}{{println .Name}}{{end}}')
}

assert_container_runtime() {
  local service=$1 expected_port=$2 expected_memory=$3 container_id binding memory
  container_id=$(RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
    -f infra/compose/compose.production.yml ps -q "$service")
  [[ -n "$container_id" ]] || { echo "production service is missing: $service" >&2; exit 1; }
  memory=$(docker inspect --format '{{.HostConfig.Memory}}' "$container_id")
  [[ "$memory" == "$expected_memory" ]] || {
    echo "$service memory limit mismatch: $memory" >&2
    exit 1
  }
  case "$service" in
    backend) binding=$(docker inspect --format '{{(index (index .HostConfig.PortBindings "8080/tcp") 0).HostIp}}:{{(index (index .HostConfig.PortBindings "8080/tcp") 0).HostPort}}' "$container_id") ;;
    mysql) binding=$(docker inspect --format '{{(index (index .HostConfig.PortBindings "3306/tcp") 0).HostIp}}:{{(index (index .HostConfig.PortBindings "3306/tcp") 0).HostPort}}' "$container_id") ;;
    mongo) binding=$(docker inspect --format '{{(index (index .HostConfig.PortBindings "27017/tcp") 0).HostIp}}:{{(index (index .HostConfig.PortBindings "27017/tcp") 0).HostPort}}' "$container_id") ;;
  esac
  [[ "$binding" == "127.0.0.1:$expected_port" ]] || {
    echo "$service host binding mismatch: $binding" >&2
    exit 1
  }
}

restore_nginx() {
  local host_sha container_sha
  if ! cat "$backup" >"$nginx_conf"; then
    echo 'failed to restore the host Nginx config in place' >&2
    return 1
  fi
  if [[ "$(stat -c '%i:%u:%g:%a' "$nginx_conf")" != "$original_attributes" ]]; then
    echo 'Nginx rollback restored content but file attributes changed unexpectedly' >&2
    return 1
  fi
  host_sha=$(sha256sum "$nginx_conf" | awk '{print $1}')
  container_sha=$(docker exec "$nginx_container" cat /etc/nginx/nginx.conf | sha256sum | awk '{print $1}')
  if [[ "$host_sha" != "$container_sha" ]]; then
    echo 'Nginx rollback host/container SHA-256 mismatch; shared bind-mount state requires manual inspection' >&2
    return 1
  fi
  docker exec "$nginx_container" nginx -t >/dev/null
}

validate_nginx_update() {
  local host_count container_count host_sha container_sha effective
  host_count=$(grep -cF "$begin_marker" "$nginx_conf" || true)
  [[ "$host_count" == 1 ]] || { echo "host Nginx marker count is $host_count" >&2; return 1; }
  [[ "$(grep -cF "$end_marker" "$nginx_conf" || true)" == 1 ]] || return 1
  container_count=$(docker exec "$nginx_container" cat /etc/nginx/nginx.conf | grep -cF "$begin_marker" || true)
  [[ "$container_count" == 1 ]] || { echo "container Nginx marker count is $container_count" >&2; return 1; }
  host_sha=$(sha256sum "$nginx_conf" | awk '{print $1}')
  container_sha=$(docker exec "$nginx_container" cat /etc/nginx/nginx.conf | sha256sum | awk '{print $1}')
  [[ "$host_sha" == "$container_sha" ]] || { echo 'host/container Nginx config SHA-256 mismatch' >&2; return 1; }
  [[ "$(stat -c '%i:%u:%g:%a' "$nginx_conf")" == "$original_attributes" ]] || {
    echo 'Nginx config inode/owner/group/mode changed' >&2
    return 1
  }
  docker exec "$nginx_container" nginx -t || return 1
  effective=$(docker exec "$nginx_container" nginx -T 2>&1) || return 1
  grep -Fq 'server_name wm7023.campusmeow.com;' <<<"$effective" || return 1
  grep -Fq 'listen 80;' <<<"$effective" || return 1
  grep -Fq 'listen [::]:80;' <<<"$effective" || return 1
  grep -Fq 'proxy_pass http://wm7023-backend:8080;' <<<"$effective" || return 1
  printf 'Nginx host/container SHA-256: %s\n' "$host_sha"
}

[[ -r "$git_ssh_key" ]] || { echo "server deploy key is not readable: $git_ssh_key" >&2; exit 2; }
[[ -f "$env_file" ]] || { echo "remote production env file not found: $env_file" >&2; exit 2; }
[[ "$(stat -c '%a' "$env_file")" == 600 ]] || {
  echo 'remote production env file must have mode 600' >&2
  exit 2
}
[[ -f "$nginx_conf" ]] || { echo "shared Nginx config not found: $nginx_conf" >&2; exit 2; }
docker inspect "$nginx_container" >/dev/null 2>&1 || { echo "shared Nginx container not found: $nginx_container" >&2; exit 2; }
[[ "$(docker inspect --format '{{.State.Running}}' "$nginx_container")" == true ]] || {
  echo 'shared Nginx container is not running' >&2
  exit 2
}
mounted_source=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/nginx.conf"}}{{.Source}}{{end}}{{end}}' "$nginx_container")
[[ -n "$mounted_source" && "$(readlink -f "$mounted_source")" == "$(readlink -f "$nginx_conf")" ]] || {
  echo 'shared Nginx config path does not match the container bind mount' >&2
  exit 2
}

assert_expected_setting BACKEND_HOST_PORT 18023
assert_expected_setting MYSQL_HOST_PORT 13323
assert_expected_setting MONGO_HOST_PORT 27023
assert_expected_setting BACKEND_MEMORY_LIMIT 512m
assert_expected_setting MYSQL_MEMORY_LIMIT 384m
assert_expected_setting MONGO_MEMORY_LIMIT 256m
[[ -n "$(env_value MONGO_APP_USERNAME)" ]] || { echo 'MONGO_APP_USERNAME is required' >&2; exit 2; }
[[ -n "$(env_value MONGO_APP_PASSWORD)" ]] || { echo 'MONGO_APP_PASSWORD is required' >&2; exit 2; }
[[ -n "$(env_value APP_AUTH_SIGNING_KEY)" ]] || { echo 'APP_AUTH_SIGNING_KEY is required' >&2; exit 2; }
assert_port_available 18023
assert_port_available 13323
assert_port_available 27023
assert_edge_members

export GIT_SSH_COMMAND="ssh -i $git_ssh_key -o IdentitiesOnly=yes"
git ls-remote --exit-code --tags "$repository_url" "refs/tags/$tag" >/dev/null || {
  echo "release tag is not readable with the server Deploy Key: $tag" >&2
  exit 2
}

if [[ ! -d "$deploy_dir/.git" ]]; then
  if [[ -e "$deploy_dir" ]] && [[ -n "$(find "$deploy_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "deployment directory exists but is not an empty Git checkout: $deploy_dir" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$deploy_dir")"
  git clone "$repository_url" "$deploy_dir"
fi

cd "$deploy_dir"
git diff --quiet && git diff --cached --quiet || { echo 'remote checkout has tracked changes' >&2; exit 2; }
git fetch --tags origin
git checkout --detach "$tag"
[[ "$(git describe --tags --exact-match)" == "$tag" ]] || { echo 'remote checkout does not match requested tag' >&2; exit 2; }
RELEASE_VERSION=${tag#v}
GIT_COMMIT=$(git rev-parse HEAD)
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export RELEASE_VERSION GIT_COMMIT BUILD_TIME

docker network inspect "$edge_network" >/dev/null 2>&1 || docker network create "$edge_network" >/dev/null
RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
  -f infra/compose/compose.production.yml config >/dev/null
RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
  -f infra/compose/compose.production.yml build backend
RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
  -f infra/compose/compose.production.yml up -d mysql mongo

mongo_id=$(RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
  -f infra/compose/compose.production.yml ps -q mongo)
for attempt in $(seq 1 30); do
  [[ "$(docker inspect --format '{{.State.Health.Status}}' "$mongo_id")" == healthy ]] && break
  [[ "$attempt" -lt 30 ]] && sleep 2
done
[[ "$(docker inspect --format '{{.State.Health.Status}}' "$mongo_id")" == healthy ]] || {
  echo 'production MongoDB did not become healthy' >&2
  exit 1
}
docker exec -i \
  -e MONGO_DATABASE="$(env_value MONGO_DATABASE)" \
  -e MONGO_APP_USERNAME="$(env_value MONGO_APP_USERNAME)" \
  -e MONGO_APP_PASSWORD="$(env_value MONGO_APP_PASSWORD)" \
  -e MONGO_ADMIN_USERNAME="$(env_value MONGO_INITDB_ROOT_USERNAME)" \
  -e MONGO_ADMIN_PASSWORD="$(env_value MONGO_INITDB_ROOT_PASSWORD)" \
  "$mongo_id" sh -c 'mongosh --quiet --username "$MONGO_ADMIN_USERNAME" \
    --password "$MONGO_ADMIN_PASSWORD" --authenticationDatabase admin' \
  <infra/production/mongo/init-app-user.js >/dev/null

RELEASE_IMAGE_TAG="$tag" docker compose --env-file "$env_file" -p "$project" \
  -f infra/compose/compose.production.yml up -d --no-deps backend

backend_port=$(env_value BACKEND_HOST_PORT)
for attempt in $(seq 1 60); do
  if curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null; then
    break
  fi
  [[ "$attempt" -lt 60 ]] && sleep 2
done
curl --fail --silent "http://127.0.0.1:${backend_port}/actuator/health" >/dev/null
assert_container_runtime backend 18023 536870912
assert_container_runtime mysql 13323 402653184
assert_container_runtime mongo 27023 268435456

if ! docker network inspect "$edge_network" --format '{{range .Containers}}{{println .Name}}{{end}}' | grep -Fxq "$nginx_container"; then
  docker network connect "$edge_network" "$nginx_container"
fi
assert_edge_members

updated=$(mktemp)
backup="${nginx_conf}.bak.${tag//[^A-Za-z0-9_.-]/_}.$(date +%Y%m%d%H%M%S)"
trap 'rm -f "$updated"' EXIT
cp --preserve=all -- "$nginx_conf" "$backup"
original_attributes=$(stat -c '%i:%u:%g:%a' "$nginx_conf")
scripts/render-nginx-config.sh "$nginx_conf" infra/nginx/backend.conf.template "$updated"
if ! cat "$updated" >"$nginx_conf"; then
  restore_nginx
  echo 'failed to update the host Nginx config; restored the original config in place' >&2
  exit 1
fi
if ! validate_nginx_update; then
  restore_nginx
  echo 'Nginx validation failed; restored the previous shared configuration in place' >&2
  exit 1
fi
if ! docker exec "$nginx_container" nginx -s reload; then
  restore_nginx
  docker exec "$nginx_container" nginx -s reload
  echo 'Nginx reload failed; restored and reloaded the previous shared configuration' >&2
  exit 1
fi
REMOTE
