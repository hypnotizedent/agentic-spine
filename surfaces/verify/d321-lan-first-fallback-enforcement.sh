#!/usr/bin/env bash
# TRIAGE: Check that scoped status scripts use binding-driven host resolution (no hardcoded shop LAN IPs) and that ssh-resolve.sh provides fallback.
# Gate: D321 — lan-first-fallback-enforcement
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail=0
pass=0
total=0

check() {
  local label="$1"
  local result="$2"
  total=$((total + 1))
  if [[ "$result" == "PASS" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label"
    fail=$((fail + 1))
  fi
}

echo "D321: lan-first-fallback-enforcement"
echo

# ── 1. ssh-resolve.sh must export ssh_resolve_host_with_fallback ─────────
if grep -q 'ssh_resolve_host_with_fallback' "$SPINE_ROOT/ops/lib/ssh-resolve.sh" 2>/dev/null; then
  check "ssh-resolve.sh provides ssh_resolve_host_with_fallback" "PASS"
else
  check "ssh-resolve.sh provides ssh_resolve_host_with_fallback" "FAIL"
fi

# ── 2. ssh-target-status must have fallback logic for lan_first ──────────
if grep -q 'access_policy.*lan_first\|tailscale_ip\|path_used\|effective_host' \
  "$SPINE_ROOT/ops/plugins/ssh/bin/ssh-target-status" 2>/dev/null; then
  check "ssh-target-status has lan_first fallback logic" "PASS"
else
  check "ssh-target-status has lan_first fallback logic" "FAIL"
fi

# ── 3. Scoped scripts must NOT hardcode shop LAN target selection ────────
SCOPED_SCRIPTS=(
  "$SPINE_ROOT/ops/plugins/observability/bin/finance-stack-status"
  "$SPINE_ROOT/ops/plugins/observability/bin/observability-stack-status"
  "$SPINE_ROOT/ops/plugins/infra/bin/infra-docker-host-status"
  "$WORKBENCH_ROOT/agents/media/tools/src/spine-plugin-media/bin/media-status"
)

for script in "${SCOPED_SCRIPTS[@]}"; do
  name="$(basename "$script")"
  if [[ ! -f "$script" ]]; then
    check "$name exists" "FAIL"
    continue
  fi

  # Check for hardcoded shop LAN IP as a primary variable assignment (e.g. HOST_IP="192.168.1.xxx")
  # Allow: comments, conditional fallback defaults (&& VAR=), and URL strings in bindings
  if grep -E '^[^#]*[A-Z_]+IP["\x27]*=["'\'']*192\.168\.1\.' "$script" 2>/dev/null \
     | grep -vE '&&.*=|^\s*#' >/dev/null 2>&1; then
    check "$name: no hardcoded shop LAN IP assignment" "FAIL"
  else
    check "$name: no hardcoded shop LAN IP assignment" "PASS"
  fi

  # Check that script sources ssh-resolve.sh or uses ssh_resolve_host_with_fallback
  if grep -qE 'ssh-resolve\.sh|ssh_resolve_host_with_fallback' "$script" 2>/dev/null; then
    check "$name: uses binding-driven resolver" "PASS"
  else
    check "$name: uses binding-driven resolver" "FAIL"
  fi
done

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
