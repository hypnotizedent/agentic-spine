#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$ROOT/surfaces/verify/d75-gap-registry-mutation-lock.sh"

unset SPINE_STATE 2>/dev/null || true
unset GAPS_DB_PATH 2>/dev/null || true
unset GAPS_YAML_PATH 2>/dev/null || true

output="$(bash "$SCRIPT" 2>&1)"
printf '%s\n' "$output"

echo "$output" | grep -q "D75 PASS: gap registry mutation lock"
