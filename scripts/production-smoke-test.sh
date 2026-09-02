#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT="engineering-acceptance-production-smoke-${BASHPID}-$(date +%s)"
SMOKE_IMAGE_TAG="smoke-${BASHPID}-$(date +%s)"
SMOKE_RELEASE_VERSION="0.0.0-smoke.${BASHPID}"
SMOKE_BACKEND_HOST_PORT=$((30000 + BASHPID % 20000))
GIT_COMMIT=$(git -C "$ROOT_DIR" rev-parse HEAD)
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export SMOKE_IMAGE_TAG SMOKE_RELEASE_VERSION SMOKE_BACKEND_HOST_PORT GIT_COMMIT BUILD_TIME

COMPOSE=(docker compose -p "$PROJECT" --env-file "$ROOT_DIR/infra/env/test.env.example"
  -f "$ROOT_DIR/infra/compose/compose.production-smoke.yml")

cleanup() {
  "${COMPOSE[@]}" down --volumes --remove-orphans
  docker image rm "engineering-acceptance-backend:$SMOKE_IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ -n "$(docker ps --filter "publish=$SMOKE_BACKEND_HOST_PORT" --format '{{.Names}}')" ]]; then
  echo "temporary smoke port is already used: $SMOKE_BACKEND_HOST_PORT" >&2
  exit 2
fi

wait_for_health() {
  local attempt
  for attempt in $(seq 1 60); do
    if curl --fail --silent "http://127.0.0.1:$SMOKE_BACKEND_HOST_PORT/actuator/health" >/dev/null; then
      return 0
    fi
    [[ "$attempt" -lt 60 ]] && sleep 2
  done
  return 1
}

mysql_query() {
  local sql=$1
  "${COMPOSE[@]}" exec -T mysql sh -c \
    "mysql -N -u root -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" -e \"\$1\"" sh "$sql"
}

api_request() {
  local method=$1 path=$2 body=${3:-} token=${4:-}
  local -a headers=(--header 'Content-Type: application/json')
  if [[ -n "$token" ]]; then
    headers+=(--header "Authorization: Bearer $token")
  fi
  if [[ -n "$body" ]]; then
    curl --fail --silent --request "$method" \
      "${headers[@]}" \
      --data "$body" "http://127.0.0.1:$SMOKE_BACKEND_HOST_PORT$path"
  else
    curl --fail --silent --request "$method" \
      "${headers[@]}" \
      "http://127.0.0.1:$SMOKE_BACKEND_HOST_PORT$path"
  fi
}

"${COMPOSE[@]}" up -d --build
wait_for_health

build_info=$(api_request GET /actuator/info)
[[ "$build_info" == *"\"version\":\"$SMOKE_RELEASE_VERSION\""* ]]
[[ "$build_info" == *"\"commit\":\"$GIT_COMMIT\""* ]]

migration_before=$(mysql_query \
  "SELECT CONCAT(COUNT(*), ':', COALESCE(SUM(success), 0)) FROM flyway_schema_history WHERE version = '1';")
[[ "$migration_before" == "1:1" ]]
[[ "$(mysql_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'users';")" == 1 ]]

registration=$(api_request POST /api/auth/register \
  '{"username":"production-smoke-user","password":"password123","nickname":"Production Smoke"}')
[[ "$registration" == *'"tokenType":"Bearer"'* && "$registration" != *passwordHash* ]]
user_id=$(sed -n 's/.*"user":{"id":\([0-9][0-9]*\).*/\1/p' <<<"$registration")
access_token=$(sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p' <<<"$registration")
[[ -n "$user_id" ]]
[[ -n "$access_token" ]]

password_hash=$(mysql_query \
  "SELECT password_hash FROM users WHERE username = 'production-smoke-user';")
[[ "$password_hash" != "password123" && "$password_hash" == \$2* ]]

login=$(api_request POST /api/auth/login \
  '{"username":"production-smoke-user","password":"password123"}')
[[ "$login" == *"\"user\":{\"id\":$user_id"* && "$login" != *passwordHash* ]]

profile=$(api_request GET "/api/users/$user_id" '' "$access_token")
[[ "$profile" == *'"nickname":"Production Smoke"'* && "$profile" != *passwordHash* ]]

updated=$(api_request PUT "/api/users/$user_id" \
  '{"nickname":"Updated Production Smoke","birthday":"2001-02-03","school":"Campus Meow","className":"Class 1"}' \
  "$access_token")
[[ "$updated" == *'"nickname":"Updated Production Smoke"'* && "$updated" != *passwordHash* ]]

created_post=$(api_request POST /api/posts \
  '{"title":"Production smoke post","content":"Persistent MongoDB smoke data"}' "$access_token")
[[ "$created_post" == *"\"authorUserId\":$user_id"* && "$created_post" == *'"title":"Production smoke post"'* ]]
posts=$(api_request GET /api/posts)
[[ "$posts" == *'"title":"Production smoke post"'* ]]

"${COMPOSE[@]}" restart backend
wait_for_health

migration_after=$(mysql_query \
  "SELECT CONCAT(COUNT(*), ':', COALESCE(SUM(success), 0)) FROM flyway_schema_history WHERE version = '1';")
[[ "$migration_after" == "$migration_before" ]]
[[ "$(mysql_query "SELECT COUNT(*) FROM users WHERE username = 'production-smoke-user';")" == 1 ]]

login_after_restart=$(api_request POST /api/auth/login \
  '{"username":"production-smoke-user","password":"password123"}')
[[ "$login_after_restart" == *"\"user\":{\"id\":$user_id"* && "$login_after_restart" != *passwordHash* ]]
posts_after_restart=$(api_request GET /api/posts)
[[ "$posts_after_restart" == *'"title":"Production smoke post"'* ]]

printf 'Production-like smoke passed: Flyway V1=%s; restart V1=%s; data persisted.\n' \
  "$migration_before" "$migration_after"
