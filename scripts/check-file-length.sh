#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
status=0
while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file")
  if (( lines > 800 )); then
    printf 'file too long (%s lines): %s\n' "$lines" "$file" >&2
    status=1
  fi
done < <(find "$ROOT_DIR/frontend" "$ROOT_DIR/backend/src" -type f \( -name '*.dart' -o -name '*.java' \) -print0)
exit "$status"
