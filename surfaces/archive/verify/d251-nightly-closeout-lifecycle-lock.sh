#!/usr/bin/env bash
# TRIAGE: Restore nightly closeout wiring/contracts before enabling scheduled closeout runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CONTRACT="$ROOT/ops/bindings/nightly.closeout.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
CAPMAP="$ROOT/ops/bindings/capability_map.yaml"
ROUTING="$ROOT/ops/bindings/routing.dispatch.yaml"
CMD="$ROOT/ops/commands/nightly-closeout.sh"
SESSION_PROTOCOL="$ROOT/docs/governance/SESSION_PROTOCOL.md"
GOV_BRIEF="$ROOT/docs/governance/AGENT_GOVERNANCE_BRIEF.md"

if command -v rg >/dev/null 2>&1; then
  FIND_CMD="rg -F -n --no-messages"
else
  FIND_CMD="grep -F -n"
fi

failures=0

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; failures=$((failures + 1)); }

check_file() {
  local f="$1" label="$2"
  [[ -f "$f" ]] && pass "$label exists" || fail "$label missing ($f)"
}

check_exec() {
  local f="$1" label="$2"
  [[ -x "$f" ]] && pass "$label executable" || fail "$label not executable ($f)"
}

check_contains() {
  local f="$1" needle="$2" label="$3"
  if eval "$FIND_CMD \"\$needle\" \"\$f\"" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label (missing '$needle' in $f)"
  fi
}

echo "D251 Nightly Closeout Lifecycle Lock"
echo "root=$ROOT"

# Required files
check_file "$CONTRACT" "nightly contract"
check_file "$CAPS" "capabilities registry"
check_file "$CAPMAP" "capability map"
check_file "$ROUTING" "routing dispatch"
check_file "$CMD" "nightly closeout command"
check_exec "$CMD" "nightly closeout command"
check_file "$SESSION_PROTOCOL" "session protocol doc"
check_file "$GOV_BRIEF" "governance brief doc"

# Contract lock checks
check_contains "$CONTRACT" "capability: nightly.closeout" "contract binds nightly.closeout capability"
check_contains "$CONTRACT" "require_dry_run_before_apply: true" "contract requires dry-run before apply"
check_contains "$CONTRACT" "require_snapshot_before_destructive: true" "contract requires snapshot before destructive actions"
check_contains "$CONTRACT" "LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226" "contract protects active mail loop"
check_contains "$CONTRACT" "GAP-OP-973" "contract protects active mail gap"
check_contains "$CONTRACT" "gate: D205" "contract pins accepted D205 baseline exception"
check_contains "$CONTRACT" "require_master_receipt: true" "contract requires master receipt"
check_contains "$CONTRACT" "require_dryrun_receipt: true" "contract requires dry-run receipt"
check_contains "$CONTRACT" "require_apply_receipt: true" "contract requires apply receipt"

# Wiring checks
check_contains "$CAPS" "nightly.closeout" "capabilities registry includes nightly.closeout"
check_contains "$CAPMAP" "nightly.closeout" "capability map includes nightly.closeout"
check_contains "$ROUTING" "nightly.closeout" "routing dispatch includes nightly.closeout"

# Command behavior checks
check_contains "$CMD" "dry-run" "nightly command supports dry-run mode"
check_contains "$CMD" "apply" "nightly command supports apply mode"

# Governance docs mention canonical entrypoint
check_contains "$SESSION_PROTOCOL" "nightly.closeout" "session protocol documents nightly closeout"
check_contains "$GOV_BRIEF" "nightly.closeout" "governance brief documents nightly closeout"

if [[ "$failures" -gt 0 ]]; then
  echo "D251 FAIL: $failures check(s) failed"
  exit 1
fi

echo "D251 PASS: lifecycle lock is canonical and wired"
