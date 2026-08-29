#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
if rg -n --hidden --glob '!.git/**' --glob '!**/*.lock' --glob '!infra/env/*.example' \
  '(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|ghp_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,})' \
  "$ROOT_DIR"; then
  echo 'possible secret detected' >&2
  exit 1
fi
