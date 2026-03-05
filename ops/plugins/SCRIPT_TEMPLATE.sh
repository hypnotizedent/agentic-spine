#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
# Canonical path resolver requirement for all new plugin scripts.
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

usage() {
  cat <<'USAGE'
script-template

Usage:
  script-template [--json]
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

json_mode=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) json_mode=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown arg: $1" ;;
  esac
  shift
done

if [[ "$json_mode" -eq 1 ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq -cn \
      --arg status "ok" \
      --arg timestamp_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{status:$status,timestamp_utc:$timestamp_utc}'
  else
    printf '{"status":"ok","timestamp_utc":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
  exit 0
fi

echo "script-template"
echo "status: ok"

