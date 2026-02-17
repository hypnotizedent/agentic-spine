#!/usr/bin/env bash
# TRIAGE: Validate dynamic entry surfaces (spine.context + retired sync hooks).
set -euo pipefail

# D56: Agent Entry Surface Lock (composite)
# Groups the common "agent entry/read surfaces out of sync" checks behind one STOP.
#
# Subchecks:
#   - D26 agent read surface drift
#   - D32 codex instruction source lock
#   - D46 claude instruction source lock
#   - Legacy sync hooks are retired shims (WS-5)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC_AGENT_HOOK="$ROOT/ops/hooks/sync-agent-surfaces.sh"
SYNC_SLASH_HOOK="$ROOT/ops/hooks/sync-slash-commands.sh"

fail() { echo "D56 FAIL: $*" >&2; exit 1; }

subcheck() {
  local id="$1"
  local script="$2"
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    rm -f "$tmp"
    return 0
  fi

  echo "subcheck ${id}: FAIL (rc=${rc})" >&2
  sed -n '1,80p' "$tmp" >&2 || true
  rm -f "$tmp"
  return 1
}

retired_hook_check() {
  local path="$1"
  local id="$2"

  if [[ ! -f "$path" ]]; then
    echo "subcheck ${id}: FAIL (missing retired hook shim: $path)" >&2
    return 1
  fi

  if ! grep -qF "RETIRED" "$path" 2>/dev/null; then
    echo "subcheck ${id}: FAIL (hook still appears active: $path)" >&2
    return 1
  fi

  return 0
}

FAILS=0

subcheck "D26" "$ROOT/surfaces/verify/d26-agent-read-surface.sh" || FAILS=$((FAILS+1))
subcheck "D32" "$ROOT/surfaces/verify/d32-codex-instruction-source-lock.sh" || FAILS=$((FAILS+1))
subcheck "D46" "$ROOT/surfaces/verify/d46-claude-instruction-source-lock.sh" || FAILS=$((FAILS+1))
retired_hook_check "$SYNC_AGENT_HOOK" "WS5-sync-agent-surfaces" || FAILS=$((FAILS+1))
retired_hook_check "$SYNC_SLASH_HOOK" "WS5-sync-slash-commands" || FAILS=$((FAILS+1))

(( FAILS == 0 )) || fail "agent entry surface violated (${FAILS} failing subcheck(s))"
exit 0
