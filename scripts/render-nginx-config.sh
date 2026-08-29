#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 3 ]]; then
  echo 'usage: render-nginx-config.sh <existing-config> <server-template> <output>' >&2
  exit 2
fi

existing_config=$1
server_template=$2
output=$3
begin_marker='# BEGIN engineering-acceptance wm7023 block'
end_marker='# END engineering-acceptance wm7023 block'

[[ -f "$existing_config" ]] || { echo "existing Nginx config not found: $existing_config" >&2; exit 2; }
[[ -f "$server_template" ]] || { echo "Nginx template not found: $server_template" >&2; exit 2; }
[[ "$output" != "$existing_config" ]] || { echo 'output must differ from existing config' >&2; exit 2; }

payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
{
  printf '%s\n' "$begin_marker"
  sed -n '1,$p' "$server_template"
  printf '%s\n' "$end_marker"
} >"$payload"

awk -v payload="$payload" -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
  BEGIN { in_http = 0; depth = 0; inserted = 0; skipping = 0 }
  $0 == begin_marker { skipping = 1; next }
  skipping && $0 == end_marker { skipping = 0; next }
  {
    if (skipping) next
    opens = gsub(/\{/, "&")
    closes = gsub(/\}/, "&")
    if ($0 ~ /^[[:space:]]*http[[:space:]]*\{/) in_http = 1
    if (in_http && !inserted && depth == 1 && closes > 0) {
      while ((getline line < payload) > 0) print line
      close(payload)
      inserted = 1
    }
    print
    depth += opens - closes
  }
  END { if (!inserted) exit 42 }
' "$existing_config" >"$output"
