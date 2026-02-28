#!/usr/bin/env bash
# TRIAGE: alert when critical asset capability exists but has no operational use over threshold window.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/critical.asset.utilization.contract.yaml"
INDEX="$ROOT/ops/plugins/evidence/state/receipt-index.yaml"

fail() {
  echo "D286 FAIL: $*" >&2
  exit 1
}

for f in "$CONTRACT" "$INDEX"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

now_epoch="$(date -u +%s)"
errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

asset_count="$(yq e '.assets | length' "$CONTRACT")"
for ((i=0; i<asset_count; i++)); do
  asset_id="$(yq e -r ".assets[$i].asset_id // \"\"" "$CONTRACT")"
  threshold="$(yq e -r ".assets[$i].usage_threshold_days // 0" "$CONTRACT")"
  [[ -n "$asset_id" ]] || { err "asset[$i] missing asset_id"; continue; }
  [[ "$threshold" =~ ^[0-9]+$ ]] || { err "$asset_id invalid usage_threshold_days"; continue; }

  newest_epoch=0
  mapfile -t caps < <(yq e -r ".assets[$i].capabilities[]? // \"\"" "$CONTRACT" | sed '/^$/d')
  [[ "${#caps[@]}" -gt 0 ]] || { err "$asset_id has no capabilities"; continue; }

  for cap in "${caps[@]}"; do
    latest="$(yq e -r ".entries[] | select(.capability == \"$cap\") | .generated_at_utc" "$INDEX" 2>/dev/null | tail -1)"
    [[ -n "$latest" ]] || continue
    cap_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$latest" +%s 2>/dev/null || true)"
    if [[ -n "$cap_epoch" && "$cap_epoch" =~ ^[0-9]+$ ]]; then
      [[ "$cap_epoch" -gt "$newest_epoch" ]] && newest_epoch="$cap_epoch"
    fi
  done

  if [[ "$newest_epoch" -eq 0 ]]; then
    err "$asset_id has zero observed capability usage in receipt index"
    continue
  fi

  age_days=$(( (now_epoch - newest_epoch) / 86400 ))
  if [[ "$age_days" -gt "$threshold" ]]; then
    err "$asset_id usage stale: last evidence ${age_days}d ago (threshold=${threshold}d)"
  fi
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors utilization/freshness violation(s)"
fi

echo "D286 PASS: critical asset utilization/freshness lock enforced"
