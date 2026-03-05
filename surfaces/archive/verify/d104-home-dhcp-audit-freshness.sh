#!/usr/bin/env bash
# TRIAGE: DHCP audit summary missing or stale — run network.home.dhcp.audit to regenerate ops/bindings/home.dhcp.audit.yaml
# D104: home-dhcp-audit-freshness
# Enforces: home.dhcp.audit.yaml exists, has registry_devices_checked > 0, freshness < 14 days
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/home.dhcp.audit.yaml"

if [[ ! -f "$BINDING" ]]; then
  echo "D104 FAIL: home.dhcp.audit.yaml does not exist"
  exit 1
fi

# Check registry_devices_checked > 0
count="$(yq -r '.summary.registry_devices_checked // 0' "$BINDING" 2>/dev/null)"
if [[ "$count" -lt 1 ]]; then
  echo "D104 FAIL: home.dhcp.audit.yaml has 0 devices checked"
  exit 1
fi

# Check freshness (generated timestamp < 14 days old)
generated="$(yq -r '.generated // ""' "$BINDING" 2>/dev/null)"
if [[ -z "$generated" ]]; then
  echo "D104 FAIL: home.dhcp.audit.yaml missing generated timestamp"
  exit 1
fi

gen_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$generated" '+%s' 2>/dev/null || date -d "$generated" '+%s' 2>/dev/null || echo 0)"
now_epoch="$(date '+%s')"
age_days=$(( (now_epoch - gen_epoch) / 86400 ))

if [[ "$age_days" -gt 14 ]]; then
  echo "D104 FAIL: home.dhcp.audit.yaml is ${age_days}d old (max 14d)"
  exit 1
fi

echo "D104 PASS (${count} devices checked, ${age_days}d old)"
exit 0
