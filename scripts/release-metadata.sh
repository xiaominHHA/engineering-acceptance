#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

resolve_release_metadata() {
  local exact_tag dirty_suffix short_sha version_code major minor patch

  GIT_COMMIT=$(git -C "$ROOT_DIR" rev-parse HEAD)
  short_sha=${GIT_COMMIT:0:12}
  BUILD_TIME=${BUILD_TIME:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  exact_tag=$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)
  dirty_suffix=''
  if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet ||
      [[ -n "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard)" ]]; then
    dirty_suffix='.dirty'
  fi

  RELEASE_TAG=${RELEASE_TAG:-$exact_tag}
  if [[ -n "$RELEASE_TAG" ]]; then
    [[ "$RELEASE_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || {
      echo "release tag must match vMAJOR.MINOR.PATCH: $RELEASE_TAG" >&2
      return 2
    }
    major=${BASH_REMATCH[1]}
    minor=${BASH_REMATCH[2]}
    patch=${BASH_REMATCH[3]}
    [[ "$exact_tag" == "$RELEASE_TAG" ]] || {
      echo "release tag does not identify the checked-out commit: $RELEASE_TAG" >&2
      return 2
    }
    [[ -z "$dirty_suffix" ]] || {
      echo 'release builds require a clean working tree' >&2
      return 2
    }
    PROJECT_VERSION=${RELEASE_TAG#v}
    ARTIFACT_VERSION=$PROJECT_VERSION
    version_code=$((major * 1000000 + minor * 1000 + patch))
    ((version_code > 0 && version_code <= 2100000000)) || {
      echo "release version cannot be represented as an Android versionCode: $PROJECT_VERSION" >&2
      return 2
    }
    ANDROID_VERSION_NAME=$PROJECT_VERSION
    ANDROID_VERSION_CODE=$version_code
  else
    PROJECT_VERSION="0.0.0-dev.$short_sha$dirty_suffix"
    ARTIFACT_VERSION=$PROJECT_VERSION
    ANDROID_VERSION_NAME=0.0.0
    ANDROID_VERSION_CODE=1
  fi

  export RELEASE_TAG PROJECT_VERSION ARTIFACT_VERSION GIT_COMMIT BUILD_TIME
  export ANDROID_VERSION_NAME ANDROID_VERSION_CODE
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  resolve_release_metadata
  case "${1:-}" in
    --github-output)
      printf 'version=%s\ncommit=%s\n' "$ARTIFACT_VERSION" "$GIT_COMMIT"
      ;;
    '')
      printf 'version=%s\ncommit=%s\nbuild_time=%s\nandroid_version_name=%s\nandroid_version_code=%s\n' \
        "$PROJECT_VERSION" "$GIT_COMMIT" "$BUILD_TIME" \
        "$ANDROID_VERSION_NAME" "$ANDROID_VERSION_CODE"
      ;;
    *)
      echo 'usage: scripts/release-metadata.sh [--github-output]' >&2
      exit 2
      ;;
  esac
fi
