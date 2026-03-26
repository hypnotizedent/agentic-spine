#!/usr/bin/env bash
# D424: Entry gate readiness — verify that session.v3.attach enforcement
# infrastructure is in place and correctly configured.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

fail() {
  echo "D424 FAIL: $*" >&2
  exit 1
}

errors=0
err() {
  echo "  D424 FAIL: $*" >&2
  errors=$((errors + 1))
}

# 1. role.runtime.control.contract.yaml has attach_admission with read-only in required_safety
CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

ENFORCE="$(yq e -r '.attach_admission.enforce_top_level // false' "$CONTRACT" 2>/dev/null)"
[[ "$ENFORCE" == "true" ]] || err "attach_admission.enforce_top_level is not true"

SAFETY_LIST="$(yq e -r '.attach_admission.required_safety[]?' "$CONTRACT" 2>/dev/null | paste -sd, -)"
echo "$SAFETY_LIST" | grep -q 'read-only' || err "attach_admission.required_safety missing 'read-only'"
echo "$SAFETY_LIST" | grep -q 'mutating' || err "attach_admission.required_safety missing 'mutating'"
echo "$SAFETY_LIST" | grep -q 'destructive' || err "attach_admission.required_safety missing 'destructive'"

# 2. entry.gate.bypass.yaml exists and is valid
BYPASS="$ROOT/ops/bindings/entry.gate.bypass.yaml"
[[ -f "$BYPASS" ]] || err "missing bypass binding: $BYPASS"
if [[ -f "$BYPASS" ]]; then
  yq e '.' "$BYPASS" >/dev/null 2>&1 || err "invalid YAML: $BYPASS"

  # Bypass must include session.v3.attach (prevent deadlock)
  BYPASS_CAPS="$(yq e -r '.entry_gate_bypass.capabilities[]?' "$BYPASS" 2>/dev/null || true)"
  if ! echo "$BYPASS_CAPS" | grep -qx 'session\.v3\.attach'; then
    err "bypass binding missing session.v3.attach (would deadlock)"
  fi

  # Bypass list should be small (max 20 entries to prevent sprawl)
  BYPASS_COUNT="$(yq e -r '.entry_gate_bypass.capabilities | length' "$BYPASS" 2>/dev/null || echo 0)"
  if [[ "$BYPASS_COUNT" -gt 20 ]]; then
    err "bypass list has $BYPASS_COUNT entries (max 20) — review for sprawl"
  fi
fi

# 3. cap.sh reads the bypass binding (check for the merge code)
CAP_SH="$ROOT/ops/commands/cap.sh"
[[ -f "$CAP_SH" ]] || err "missing: $CAP_SH"
if [[ -f "$CAP_SH" ]]; then
  grep -q 'entry.gate.bypass.yaml' "$CAP_SH" || err "cap.sh does not reference entry.gate.bypass.yaml"
fi

if [[ "$errors" -gt 0 ]]; then
  fail "$errors issue(s) detected"
fi

echo "D424 PASS: entry gate readiness verified (enforce=$ENFORCE safety=$SAFETY_LIST bypass_count=${BYPASS_COUNT:-0})"
