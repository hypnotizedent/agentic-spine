#!/usr/bin/env bash
# TRIAGE: IoT naming parity drift. Check ha_entities + tuya_name fields in home.device.registry.yaml against naming convention.
# D117: iot-device-naming-parity
# Enforces: IoT device naming convention across device registry, HA entity IDs, and Tuya names.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="$ROOT/ops/bindings/home.device.registry.yaml"
DEVICE_MAP="$ROOT/ops/bindings/ha.device.map.yaml"
FAIL=0

err() { echo "D117 FAIL: $*" >&2; FAIL=1; }

if [[ ! -f "$REGISTRY" ]]; then
  echo "D117 FAIL: missing $REGISTRY" >&2
  exit 1
fi

# ── Helper: kebab-to-snake (office-desk-bulb → office_desk_bulb) ──
kebab_to_snake() { echo "$1" | tr '-' '_'; }

# ── Helper: kebab-to-title (office-desk-bulb → Office Desk Bulb) ──
kebab_to_title() {
  echo "$1" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

# ── Collect device IDs with ha_entities ──
HA_DEVICE_IDS="$(yq -r '.devices[] | select(has("ha_entities")) | .id' "$REGISTRY" 2>/dev/null)"
DEVICE_COUNT=$(echo "$HA_DEVICE_IDS" | grep -c . || true)

if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "D117 SKIP: no devices with ha_entities in registry"
  exit 0
fi

# ── Check 1: For Tuya devices, ha_entities match {domain}.{snake_case(id)} ──
# Non-Tuya devices (Matter/IKEA, Ring, etc.) have integration-assigned entity IDs
# that we can't rename — their ha_entities are cross-references only.
TUYA_HA_IDS="$(yq -r '.devices[] | select(has("ha_entities") and has("tuya_name")) | .id' "$REGISTRY" 2>/dev/null)"
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  snake_id="$(kebab_to_snake "$id")"

  while IFS= read -r entity; do
    [[ -z "$entity" || "$entity" == "null" ]] && continue
    domain="${entity%%.*}"
    entity_name="${entity#*.}"
    if [[ "$entity_name" != "$snake_id" ]]; then
      err "device '$id' ha_entity '$entity' does not match expected '${domain}.${snake_id}'"
    fi
  done < <(yq -r ".devices[] | select(.id == \"$id\") | .ha_entities[]" "$REGISTRY" 2>/dev/null)
done <<< "$TUYA_HA_IDS"

# ── Check 2: tuya_name matches Title Case of id ──
TUYA_DEVICE_IDS="$(yq -r '.devices[] | select(has("tuya_name")) | .id' "$REGISTRY" 2>/dev/null)"
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  tuya_name="$(yq -r ".devices[] | select(.id == \"$id\") | .tuya_name" "$REGISTRY")"
  expected_title="$(kebab_to_title "$id")"
  if [[ "$tuya_name" != "$expected_title" ]]; then
    err "device '$id' tuya_name '$tuya_name' does not match expected '$expected_title'"
  fi
done <<< "$TUYA_DEVICE_IDS"

# ── Check 3: name (UniFi reservation) matches id for managed IoT devices ──
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  name="$(yq -r ".devices[] | select(.id == \"$id\") | .name" "$REGISTRY")"

  # Skip manufacturer defaults that can't be changed in UniFi
  case "$name" in
    C545|C610*|EP25|LC*|lwip0|"Network device"|"Office") continue ;;
  esac

  if [[ "$name" != "$id" ]]; then
    err "device '$id' UniFi name '$name' does not match canonical ID"
  fi
done <<< "$HA_DEVICE_IDS"

# ── Check 4: Cross-check ha_entities exist in ha.device.map.yaml ──
if [[ -f "$DEVICE_MAP" ]]; then
  # Pre-extract all entities from device map for fast lookup
  ALL_MAP_ENTITIES="$(yq -r '.devices[].entities[]' "$DEVICE_MAP" 2>/dev/null)"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    while IFS= read -r entity; do
      [[ -z "$entity" || "$entity" == "null" ]] && continue
      if ! echo "$ALL_MAP_ENTITIES" | grep -qxF "$entity"; then
        err "device '$id' ha_entity '$entity' not found in ha.device.map.yaml"
      fi
    done < <(yq -r ".devices[] | select(.id == \"$id\") | .ha_entities[]" "$REGISTRY" 2>/dev/null)
  done <<< "$HA_DEVICE_IDS"
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS ($DEVICE_COUNT devices checked)"
else
  exit 1
fi
