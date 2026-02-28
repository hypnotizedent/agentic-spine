#!/usr/bin/env bash
# TRIAGE: freshness reconciliation must run from scheduled observed-state automation.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LAUNCHD_CONTRACT="$ROOT/ops/bindings/launchd.runtime.contract.yaml"
PLIST="$ROOT/ops/runtime/launchd/com.ronny.slo-evidence-daily.plist"
RUNTIME_SCRIPT="$ROOT/ops/runtime/slo-evidence-daily.sh"
CAPS="$ROOT/ops/capabilities.yaml"
SLO_SCRIPT="$ROOT/ops/plugins/slo/bin/slo-evidence-daily"

fail() {
  echo "D277 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

for f in "$LAUNCHD_CONTRACT" "$PLIST" "$RUNTIME_SCRIPT" "$CAPS" "$SLO_SCRIPT"; do
  [[ -f "$f" ]] || fail "missing required file: $f"
done

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

launchd_labels="$(yq e -r '.required_labels[]?' "$LAUNCHD_CONTRACT" 2>/dev/null || true)"
if ! printf '%s\n' "$launchd_labels" | grep -Fxq 'com.ronny.slo-evidence-daily'; then
  err "launchd.runtime.contract missing required label com.ronny.slo-evidence-daily"
fi

if ! rg -n --fixed-strings "<string>com.ronny.slo-evidence-daily</string>" "$PLIST" >/dev/null 2>&1; then
  err "slo-evidence launchd plist label mismatch"
fi
if ! rg -n --fixed-strings "StartCalendarInterval" "$PLIST" >/dev/null 2>&1; then
  err "slo-evidence launchd plist missing schedule (StartCalendarInterval)"
fi

if ! rg -n 'cap run slo\.evidence\.daily' "$RUNTIME_SCRIPT" >/dev/null 2>&1; then
  err "runtime schedule script must call cap run slo.evidence.daily"
fi
if ! rg -n 'cap run services\.health\.status' "$RUNTIME_SCRIPT" >/dev/null 2>&1; then
  err "runtime schedule script must include observed runtime probe (services.health.status)"
fi

cap_cmd="$(yq e -r '.capabilities."slo.evidence.daily".command // ""' "$CAPS" 2>/dev/null || true)"
if ! printf '%s\n' "$cap_cmd" | grep -Fxq './ops/plugins/slo/bin/slo-evidence-daily'; then
  err "capability mapping mismatch for slo.evidence.daily"
fi

if ! rg -n --fixed-strings 'stability-control-snapshot' "$SLO_SCRIPT" >/dev/null 2>&1; then
  err "slo evidence collector must read observed runtime state (stability-control-snapshot)"
fi
if ! rg -n --fixed-strings 'verify-topology' "$SLO_SCRIPT" >/dev/null 2>&1; then
  err "slo evidence collector must run deterministic gate snapshot (verify-topology)"
fi

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D277 PASS: runtime freshness reconciliation automation lock enforced"
