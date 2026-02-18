#!/usr/bin/env bash
# TRIAGE: Add/repair NAS identity and backup coverage in canonical bindings
# D139: NAS baseline coverage present across device registry and backup inventory contracts
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
DEVICE_REG="$ROOT/ops/bindings/home.device.registry.yaml"
BACKUP_INV="$ROOT/ops/bindings/backup.inventory.yaml"

ERRORS=0
err() { echo "  $*"; ERRORS=$((ERRORS + 1)); }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D139 FAIL: 1 check(s) failed"; exit 1; }

# ── NAS identity in device registry ──────────────────────────────────────
if [[ ! -f "$DEVICE_REG" ]]; then
  err "home.device.registry.yaml not found"
else
  nas_id="$(yq e '.devices[] | select(.id == "nas") | .id' "$DEVICE_REG" 2>/dev/null || echo "")"
  if [[ -z "$nas_id" || "$nas_id" == "null" ]]; then
    err "NAS device entry (id=nas) missing from home.device.registry.yaml"
  else
    # Check required identity fields
    nas_ip="$(yq e '.devices[] | select(.id == "nas") | .ip // ""' "$DEVICE_REG" 2>/dev/null)"
    nas_role="$(yq e '.devices[] | select(.id == "nas") | .role // ""' "$DEVICE_REG" 2>/dev/null)"
    [[ -n "$nas_ip" && "$nas_ip" != "null" ]] || err "NAS device missing 'ip' field"
    [[ -n "$nas_role" && "$nas_role" != "null" ]] || err "NAS device missing 'role' field"
  fi
fi

# ── NAS backup targets in backup inventory ───────────────────────────────
if [[ ! -f "$BACKUP_INV" ]]; then
  err "backup.inventory.yaml not found"
else
  # Check for at least one backup target with NAS path (/volume1/)
  nas_target_count="$(yq e '[.targets[] | select(.path == "/volume1/*" or .path == "/volume1/backups/*" or (.path | test("/volume1/")))] | length' "$BACKUP_INV" 2>/dev/null || echo "0")"

  # Fallback: check for any target with synology or nas in the id/description
  if [[ "$nas_target_count" -eq 0 || "$nas_target_count" == "null" ]]; then
    nas_target_count="$(yq e '[.targets[] | select(.id == "*nas*" or .id == "*offsite*" or (.storage_host // "" | test("nas|synology"; "i")))] | length' "$BACKUP_INV" 2>/dev/null || echo "0")"
  fi

  # Broader check: any target referencing synology-backups or /volume1
  if [[ "$nas_target_count" -eq 0 || "$nas_target_count" == "null" ]]; then
    if grep -q 'synology\|/volume1\|nas' "$BACKUP_INV" 2>/dev/null; then
      nas_target_count=1
    fi
  fi

  if [[ "$nas_target_count" -eq 0 ]]; then
    err "No NAS backup targets found in backup.inventory.yaml (expected synology/volume1 references)"
  fi

  # Check for offsite backup coverage (vm-offsite or similar)
  offsite_count="$(yq e '[.targets[] | select(.id == "*offsite*")] | length' "$BACKUP_INV" 2>/dev/null || echo "0")"
  if [[ "$offsite_count" -eq 0 || "$offsite_count" == "null" ]]; then
    if grep -q 'offsite' "$BACKUP_INV" 2>/dev/null; then
      offsite_count=1
    fi
  fi

  if [[ "$offsite_count" -eq 0 ]]; then
    err "No offsite backup targets found in backup.inventory.yaml"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D139 FAIL: $ERRORS coverage gaps found"
  exit 1
fi

echo "D139 PASS: NAS baseline coverage present (device registry + backup inventory)"
exit 0
