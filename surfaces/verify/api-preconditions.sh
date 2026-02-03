#!/usr/bin/env bash
set -euo pipefail

REPO="${SPINE_REPO:-$HOME/Code/agentic-spine}"
CAP_FILE="$REPO/ops/capabilities.yaml"

# Requires yq (already a core dep of ops cap)
command -v yq >/dev/null 2>&1 || { echo "ERROR: yq missing"; exit 1; }

# Any capability marked touches_api: true MUST require secrets.binding + secrets.auth.status
fails=0

mapfile -t api_caps < <(yq e '.capabilities | keys | .[]' "$CAP_FILE" | while read -r cap; do
  flag="$(yq e ".capabilities.\"$cap\".touches_api // false" "$CAP_FILE")"
  [[ "$flag" == "true" ]] && echo "$cap" || true
done)

if (( ${#api_caps[@]} == 0 )); then
  echo "OK: no touches_api capabilities declared"
  exit 0
fi

for cap in "${api_caps[@]}"; do
  reqs="$(yq e -N ".capabilities.\"$cap\".requires[]? // \"\"" "$CAP_FILE" | tr '\n' ' ')"
  if [[ "$reqs" != *"secrets.binding"* ]] || [[ "$reqs" != *"secrets.auth.status"* ]]; then
    echo "FAIL: $cap touches_api=true but missing requires: secrets.binding + secrets.auth.status"
    echo "  requires: ${reqs:-<none>}"
    fails=1
  fi
done

if [[ "$fails" -ne 0 ]]; then
  echo "STOP: API preconditions rule violated"
  exit 1
fi

echo "OK: all API capabilities declare secrets preconditions"
