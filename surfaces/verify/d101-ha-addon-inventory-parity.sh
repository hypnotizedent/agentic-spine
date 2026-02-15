#!/usr/bin/env bash
# TRIAGE: HA add-on inventory missing or stale — run ha.addons.snapshot to regenerate ops/bindings/ha.addons.yaml
# D101: ha-addon-inventory-parity
# Enforces: ha.addons.yaml exists, has addon_count > 0, freshness < 14 days
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/ha.addons.yaml"

if [[ ! -f "$BINDING" ]]; then
  echo "D101 FAIL: ha.addons.yaml does not exist"
  exit 1
fi

# Check addon_count > 0
count="$(yq -r '.addon_count // 0' "$BINDING" 2>/dev/null)"
if [[ "$count" -lt 1 ]]; then
  echo "D101 FAIL: ha.addons.yaml has 0 add-ons"
  exit 1
fi

# Check freshness (generated timestamp < 14 days old)
generated="$(yq -r '.generated // ""' "$BINDING" 2>/dev/null)"
if [[ -z "$generated" ]]; then
  echo "D101 FAIL: ha.addons.yaml missing generated timestamp"
  exit 1
fi

gen_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$generated" '+%s' 2>/dev/null || date -d "$generated" '+%s' 2>/dev/null || echo 0)"
now_epoch="$(date '+%s')"
age_days=$(( (now_epoch - gen_epoch) / 86400 ))

if [[ "$age_days" -gt 14 ]]; then
  echo "D101 FAIL: ha.addons.yaml is ${age_days}d old (max 14d)"
  exit 1
fi

echo "D101 PASS (${count} add-ons, ${age_days}d old)"
exit 0
