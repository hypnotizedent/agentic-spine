#!/usr/bin/env bash
# aof-policy-autotune — Weekly gate/check policy autotune advisor.
#
# Analyzes governance load (gate count, cap count, verify pass rates)
# against growth thresholds and generates advisory recommendations
# for policy knob adjustments. Read-only — does not modify policy.
#
# Usage: aof-policy-autotune.sh [--json]
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"
SCHEMA_VERSION="1.0.0"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
JSON_MODE=0

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
  shift
fi

# ── Load current policy ──
source "$SP/ops/lib/resolve-policy.sh" 2>/dev/null || {
  echo "ERROR: resolve-policy.sh not found" >&2
  exit 1
}
resolve_policy_knobs

active_preset="${RESOLVED_POLICY_PRESET:-balanced}"

# ── Governance load metrics ──
GATE_REGISTRY="$SP/ops/bindings/gate.registry.yaml"
CAP_FILE="$SP/ops/capabilities.yaml"
GAP_FILE="$SP/ops/bindings/operational.gaps.yaml"
RULES_FILE="$SP/ops/bindings/policy.autotune.rules.yaml"

gate_count=0
if [[ -f "$GATE_REGISTRY" ]]; then
  gate_count="$(yq e '.gates | length' "$GATE_REGISTRY" 2>/dev/null || echo 0)"
fi

cap_count=0
if [[ -f "$CAP_FILE" ]]; then
  cap_count="$(yq e '.capabilities | length' "$CAP_FILE" 2>/dev/null || echo 0)"
fi

open_gap_count=0
if [[ -f "$GAP_FILE" ]]; then
  open_gap_count="$(yq e '[.[] | select(.status == "open")] | length' "$GAP_FILE" 2>/dev/null || echo 0)"
fi

# ── Recent verify receipts analysis ──
RECEIPT_DIR="$SP/receipts/sessions"
recent_verify_pass=0
recent_verify_fail=0
recent_verify_total=0
cutoff_epoch="$(date -v-7d +%s 2>/dev/null || date -d '7 days ago' +%s 2>/dev/null || echo 0)"

if [[ -d "$RECEIPT_DIR" ]]; then
  while IFS= read -r receipt; do
    [[ -z "$receipt" ]] && continue
    receipt_ts="$(basename "$(dirname "$receipt")" | sed 's/RCAP-//' | cut -d_ -f1)"
    if [[ -n "$receipt_ts" ]]; then
      receipt_epoch="$(TZ=UTC date -jf '%Y%m%d' "$receipt_ts" +%s 2>/dev/null || echo 0)"
      if [[ "$receipt_epoch" -ge "$cutoff_epoch" ]]; then
        if grep -q '| Status | done |' "$receipt" 2>/dev/null || grep -q '| Exit Code | 0 |' "$receipt" 2>/dev/null; then
          recent_verify_pass=$((recent_verify_pass + 1))
        else
          recent_verify_fail=$((recent_verify_fail + 1))
        fi
        recent_verify_total=$((recent_verify_total + 1))
      fi
    fi
  done < <(find "$RECEIPT_DIR" -name 'receipt.md' -path '*verify*' 2>/dev/null | tail -100)
fi

pass_rate=100
if [[ "$recent_verify_total" -gt 0 ]]; then
  pass_rate=$(( (recent_verify_pass * 100) / recent_verify_total ))
fi

# ── Load autotune rules ──
gate_warn_threshold=150
gate_critical_threshold=200
cap_warn_threshold=400
cap_critical_threshold=600
gap_backlog_warn=5
gap_backlog_critical=10

if [[ -f "$RULES_FILE" ]]; then
  gate_warn_threshold="$(yq e '.thresholds.gate_count.warn // 150' "$RULES_FILE" 2>/dev/null || echo 150)"
  gate_critical_threshold="$(yq e '.thresholds.gate_count.critical // 200' "$RULES_FILE" 2>/dev/null || echo 200)"
  cap_warn_threshold="$(yq e '.thresholds.cap_count.warn // 400' "$RULES_FILE" 2>/dev/null || echo 400)"
  cap_critical_threshold="$(yq e '.thresholds.cap_count.critical // 600' "$RULES_FILE" 2>/dev/null || echo 600)"
  gap_backlog_warn="$(yq e '.thresholds.open_gaps.warn // 5' "$RULES_FILE" 2>/dev/null || echo 5)"
  gap_backlog_critical="$(yq e '.thresholds.open_gaps.critical // 10' "$RULES_FILE" 2>/dev/null || echo 10)"
fi

# ── Generate recommendations ──
recommendations=()
severity="healthy"

if [[ "$gate_count" -ge "$gate_critical_threshold" ]]; then
  recommendations+=("CRITICAL: Gate count ($gate_count) exceeds critical threshold ($gate_critical_threshold). Consider retiring always-pass gates or consolidating overlapping checks.")
  severity="critical"
elif [[ "$gate_count" -ge "$gate_warn_threshold" ]]; then
  recommendations+=("WARN: Gate count ($gate_count) approaching critical threshold ($gate_critical_threshold). Review verify pack organization for consolidation opportunities.")
  [[ "$severity" == "healthy" ]] && severity="warn"
fi

if [[ "$cap_count" -ge "$cap_critical_threshold" ]]; then
  recommendations+=("CRITICAL: Capability count ($cap_count) exceeds critical threshold ($cap_critical_threshold). Audit for unused or redundant capabilities.")
  severity="critical"
elif [[ "$cap_count" -ge "$cap_warn_threshold" ]]; then
  recommendations+=("WARN: Capability count ($cap_count) approaching critical threshold ($cap_critical_threshold). Consider capability cleanup pass.")
  [[ "$severity" == "healthy" ]] && severity="warn"
fi

if [[ "$open_gap_count" -ge "$gap_backlog_critical" ]]; then
  recommendations+=("CRITICAL: Open gap backlog ($open_gap_count) exceeds critical threshold ($gap_backlog_critical). Prioritize gap triage and closure.")
  severity="critical"
elif [[ "$open_gap_count" -ge "$gap_backlog_warn" ]]; then
  recommendations+=("WARN: Open gap backlog ($open_gap_count) approaching critical threshold ($gap_backlog_critical). Schedule gap burndown.")
  [[ "$severity" == "healthy" ]] && severity="warn"
fi

if [[ "$pass_rate" -lt 90 ]] && [[ "$recent_verify_total" -gt 5 ]]; then
  recommendations+=("WARN: Verify pass rate ($pass_rate%) below 90% over last 7 days. Investigate recurring failures.")
  [[ "$severity" == "healthy" ]] && severity="warn"
fi

if [[ "$pass_rate" -eq 100 ]] && [[ "$recent_verify_total" -gt 10 ]] && [[ "$active_preset" == "strict" ]]; then
  recommendations+=("INFO: 100% pass rate with strict preset over $recent_verify_total runs. Consider relaxing to balanced preset to reduce governance overhead.")
fi

if [[ "${#recommendations[@]}" -eq 0 ]]; then
  recommendations+=("No adjustments recommended. Governance load is within healthy thresholds.")
fi

# ── Output ──
if [[ "$JSON_MODE" -eq 1 ]]; then
  rec_json="$(printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s .)"
  jq -n \
    --arg capability "aof.policy.autotune" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "ok" \
    --arg severity "$severity" \
    --arg active_preset "$active_preset" \
    --argjson gate_count "$gate_count" \
    --argjson cap_count "$cap_count" \
    --argjson open_gap_count "$open_gap_count" \
    --argjson recent_verify_pass "$recent_verify_pass" \
    --argjson recent_verify_fail "$recent_verify_fail" \
    --argjson pass_rate "$pass_rate" \
    --argjson gate_warn "$gate_warn_threshold" \
    --argjson gate_critical "$gate_critical_threshold" \
    --argjson cap_warn "$cap_warn_threshold" \
    --argjson cap_critical "$cap_critical_threshold" \
    --argjson gap_warn "$gap_backlog_warn" \
    --argjson gap_critical "$gap_backlog_critical" \
    --argjson recommendations "$rec_json" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        severity: $severity,
        active_preset: $active_preset,
        metrics: {
          gate_count: $gate_count,
          cap_count: $cap_count,
          open_gap_count: $open_gap_count,
          verify_7d: {
            pass: $recent_verify_pass,
            fail: $recent_verify_fail,
            pass_rate_pct: $pass_rate
          }
        },
        thresholds: {
          gate_count: { warn: $gate_warn, critical: $gate_critical },
          cap_count: { warn: $cap_warn, critical: $cap_critical },
          open_gaps: { warn: $gap_warn, critical: $gap_critical }
        },
        recommendations: $recommendations
      }
    }'
  exit 0
fi

echo "═══════════════════════════════════════"
echo "  AOF POLICY AUTOTUNE"
echo "═══════════════════════════════════════"
echo ""
echo "Severity:       $severity"
echo "Active preset:  $active_preset"
echo ""
echo "Governance Load:"
echo "  Gates:        $gate_count (warn=$gate_warn_threshold, critical=$gate_critical_threshold)"
echo "  Capabilities: $cap_count (warn=$cap_warn_threshold, critical=$cap_critical_threshold)"
echo "  Open gaps:    $open_gap_count (warn=$gap_backlog_warn, critical=$gap_backlog_critical)"
echo ""
echo "Verify (7-day):"
echo "  Pass: $recent_verify_pass  Fail: $recent_verify_fail  Rate: ${pass_rate}%"
echo ""
echo "Recommendations:"
for rec in "${recommendations[@]}"; do
  echo "  - $rec"
done
echo ""
echo "═══════════════════════════════════════"
