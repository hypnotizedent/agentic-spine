#!/usr/bin/env bash
# TRIAGE: HA device map missing or stale — run ha.device.map.build to regenerate ops/bindings/ha.device.map.yaml
# D102: ha-device-map-freshness
# Enforces: ha.device.map.yaml exists, has device_count > 0, freshness < 14 days
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/ha.device.map.yaml"

if [[ ! -f "$BINDING" ]]; then
  echo "D102 FAIL: ha.device.map.yaml does not exist"
  exit 1
fi

# Check device_count > 0
count="$(yq -r '.summary.device_count // 0' "$BINDING" 2>/dev/null)"
if [[ "$count" -lt 1 ]]; then
  echo "D102 FAIL: ha.device.map.yaml has 0 devices"
  exit 1
fi

# Check freshness (generated timestamp < 14 days old)
generated="$(yq -r '.generated // ""' "$BINDING" 2>/dev/null)"
if [[ -z "$generated" ]]; then
  echo "D102 FAIL: ha.device.map.yaml missing generated timestamp"
  exit 1
fi

gen_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$generated" '+%s' 2>/dev/null || date -d "$generated" '+%s' 2>/dev/null || echo 0)"
now_epoch="$(date '+%s')"
age_days=$(( (now_epoch - gen_epoch) / 86400 ))

if [[ "$age_days" -gt 14 ]]; then
  echo "D102 FAIL: ha.device.map.yaml is ${age_days}d old (max 14d)"
  exit 1
fi

# Validate overrides file if present
OVERRIDES="$ROOT/ops/bindings/ha.device.map.overrides.yaml"
if [[ -f "$OVERRIDES" ]]; then
  ov_schema="$(yq -r '.schema_version // ""' "$OVERRIDES" 2>/dev/null)"
  if [[ -z "$ov_schema" || "$ov_schema" == "null" ]]; then
    echo "D102 FAIL: ha.device.map.overrides.yaml missing schema_version"
    exit 1
  fi
fi

echo "D102 PASS (${count} devices, ${age_days}d old)"
exit 0
