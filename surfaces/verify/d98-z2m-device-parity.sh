#!/usr/bin/env bash
# TRIAGE: z2m.devices.yaml must exist, be non-empty, and fresh (<14 days). Run ha.z2m.devices.snapshot to regenerate.
set -euo pipefail

BINDING="$SPINE_ROOT/ops/bindings/z2m.devices.yaml"
MAX_AGE_DAYS=14

# Check file exists
[[ -f "$BINDING" ]] || { echo "D98 FAIL: $BINDING does not exist"; exit 1; }

# Check non-empty (at least has devices)
if ! grep -q 'device_count:' "$BINDING" 2>/dev/null; then
  echo "D98 FAIL: $BINDING missing device_count field"
  exit 1
fi

DEVICE_COUNT=$(grep 'device_count:' "$BINDING" | head -1 | awk '{print $2}')
if [[ "$DEVICE_COUNT" == "0" || -z "$DEVICE_COUNT" ]]; then
  echo "D98 FAIL: $BINDING has 0 devices"
  exit 1
fi

# Check freshness
if [[ "$(uname)" == "Darwin" ]]; then
  FILE_AGE=$(( ( $(date +%s) - $(stat -f %m "$BINDING") ) / 86400 ))
else
  FILE_AGE=$(( ( $(date +%s) - $(stat -c %Y "$BINDING") ) / 86400 ))
fi

if (( FILE_AGE > MAX_AGE_DAYS )); then
  echo "D98 FAIL: $BINDING is ${FILE_AGE}d old (max ${MAX_AGE_DAYS}d). Run: ./bin/ops cap run ha.z2m.devices.snapshot"
  exit 1
fi

echo "D98 PASS: z2m device parity valid (${DEVICE_COUNT} devices, ${FILE_AGE}d old)"
