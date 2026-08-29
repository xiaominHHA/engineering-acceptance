#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR" && pwd)
if [[ $# -ne 1 || "$1" == latest || ! "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo 'usage: ./deploy.sh <explicit-release-tag>' >&2
  exit 2
fi
tag=$1
git -C "$ROOT_DIR" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null || {
  echo "release tag does not exist locally: $tag" >&2
  exit 2
}
echo "Deployment is intentionally not executed: server SSH, domain, ports, Nginx and resource limits are待确认."
echo "Validated release tag: $tag"
