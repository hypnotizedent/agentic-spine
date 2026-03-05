#!/usr/bin/env bash
# D365: mailroom-outbox-retention-lock
# Ensure stale outbox artifacts are archived per retention policy.
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
CHECK_BIN="${ROOT}/ops/plugins/mailroom-bridge/bin/mailroom-outbox-retention"

if [[ ! -x "$CHECK_BIN" ]]; then
  echo "D365 FAIL: missing retention binary: $CHECK_BIN" >&2
  exit 1
fi

if SPINE_REPO="$ROOT" SPINE_ROOT="$ROOT" "$CHECK_BIN" --check; then
  echo "D365 PASS: outbox retention policy clean"
  exit 0
fi

echo "D365 FAIL: stale outbox artifacts exceed retention policy (run mailroom.outbox.retention --execute)" >&2
exit 1
