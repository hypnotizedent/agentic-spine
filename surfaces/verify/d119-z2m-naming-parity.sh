#!/usr/bin/env bash
# TRIAGE: Z2M naming parity drift. Check z2m.naming.yaml canonical names match z2m.devices.yaml friendly_name. Run ha.z2m.devices.snapshot + ha.device.map.build to refresh.
# D119: z2m-naming-parity
# Validates: naming parity across z2m.naming.yaml, z2m.devices.yaml, and ha.device.map.yaml.
# No HA API needed — pure file-to-file parity check.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
NAMING_BINDING="$SPINE_ROOT/ops/bindings/z2m.naming.yaml"
DEVICES_BINDING="$SPINE_ROOT/ops/bindings/z2m.devices.yaml"
DEVICE_MAP="$SPINE_ROOT/ops/bindings/ha.device.map.yaml"
FAIL=0

err() { echo "D119 FAIL: $*" >&2; FAIL=1; }

command -v yq >/dev/null 2>&1 || { echo "D119 SKIP: yq not available"; exit 0; }

if [[ ! -f "$NAMING_BINDING" ]]; then
  echo "D119 FAIL: z2m.naming.yaml missing"
  exit 1
fi

if [[ ! -f "$DEVICES_BINDING" ]]; then
  echo "D119 FAIL: z2m.devices.yaml missing"
  exit 1
fi

# ── Check 1: Every device in naming binding exists in devices binding (by IEEE) ──

NAMING_COUNT=$(yq '.devices | length' "$NAMING_BINDING")
DEVICES_COUNT=$(yq '.z2m_devices.device_count' "$DEVICES_BINDING")
i=0

while [ "$i" -lt "$NAMING_COUNT" ]; do
  CANONICAL=$(yq ".devices[$i].canonical_name" "$NAMING_BINDING")
  IEEE=$(yq ".devices[$i].ieee" "$NAMING_BINDING")
  EXPECTED_FNAME=$(yq ".devices[$i].z2m_friendly_name" "$NAMING_BINDING")

  # Check device exists in z2m.devices.yaml by IEEE
  MATCH=$(yq ".z2m_devices.devices[] | select(.ieee_address == \"$IEEE\") | .ieee_address" "$DEVICES_BINDING")
  if [[ -z "$MATCH" || "$MATCH" == "null" ]]; then
    err "$CANONICAL (IEEE $IEEE) not found in z2m.devices.yaml"
    i=$((i + 1))
    continue
  fi

  # ── Check 2: friendly_name matches ──
  ACTUAL_FNAME=$(yq ".z2m_devices.devices[] | select(.ieee_address == \"$IEEE\") | .friendly_name" "$DEVICES_BINDING")
  if [[ "$ACTUAL_FNAME" != "$EXPECTED_FNAME" ]]; then
    err "$CANONICAL friendly_name mismatch: naming='$EXPECTED_FNAME' devices='$ACTUAL_FNAME'"
  fi

  i=$((i + 1))
done

# ── Check 3: Device count parity ──

if [[ "$NAMING_COUNT" -ne "$DEVICES_COUNT" ]]; then
  err "device count mismatch: naming=$NAMING_COUNT devices=$DEVICES_COUNT"
fi

# ── Check 4: ha.device.map.yaml cross-reference ──

if [[ -f "$DEVICE_MAP" ]]; then
  i=0
  while [ "$i" -lt "$NAMING_COUNT" ]; do
    IEEE=$(yq ".devices[$i].ieee" "$NAMING_BINDING")
    CANONICAL=$(yq ".devices[$i].canonical_name" "$NAMING_BINDING")

    MAP_MATCH=$(yq ".devices[] | select(.z2m_ieee == \"$IEEE\") | .z2m_ieee" "$DEVICE_MAP")
    if [[ -z "$MAP_MATCH" || "$MAP_MATCH" == "null" ]]; then
      err "$CANONICAL (IEEE $IEEE) not found in ha.device.map.yaml z2m cross-references"
    fi

    i=$((i + 1))
  done
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS ($NAMING_COUNT devices, all parity checks OK)"
else
  exit 1
fi
