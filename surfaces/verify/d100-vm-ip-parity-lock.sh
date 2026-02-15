#!/usr/bin/env bash
# TRIAGE: VM LAN IP mismatch between vm.lifecycle.yaml and DEVICE_IDENTITY_SSOT.md — update both SSOTs to match live truth
# D100: vm-ip-parity-lock
# Enforces: vm.lifecycle.yaml lan_ip matches DEVICE_IDENTITY_SSOT.md Shop VM LAN IPs table
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
CHECKED=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
DEVICE_SSOT="$ROOT/docs/governance/DEVICE_IDENTITY_SSOT.md"

# ── Check 1: Both files exist ──
if [[ ! -f "$VM_LIFECYCLE" ]]; then
  err "vm.lifecycle.yaml does not exist"
  echo "D100 FAIL: $ERRORS check(s) failed"
  exit 1
fi
if [[ ! -f "$DEVICE_SSOT" ]]; then
  err "DEVICE_IDENTITY_SSOT.md does not exist"
  echo "D100 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "both SSOT files exist"

# ── Check 2: Extract active shop VMs with lan_ip from vm.lifecycle.yaml ──
if ! command -v yq >/dev/null 2>&1; then
  err "yq not installed"
  echo "D100 FAIL: $ERRORS check(s) failed"
  exit 1
fi

# Get hostname:lan_ip pairs for active shop VMs with non-null lan_ip
lifecycle_data="$(yq -r '.vms[] | select(.status == "active" and .proxmox_host == "pve" and .lan_ip != null) | "\(.hostname):\(.lan_ip)"' "$VM_LIFECYCLE" 2>/dev/null)"

if [[ -z "$lifecycle_data" ]]; then
  err "no active shop VMs with lan_ip found in vm.lifecycle.yaml"
  echo "D100 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "extracted VM lifecycle data"

# ── Check 3: Extract Shop VM LAN IPs from DEVICE_IDENTITY_SSOT.md ──
# The table starts after "### Shop VM LAN IPs" header and has format:
# | VM | Canonical Name | LAN IP | VMID | MAC | Notes |
ssot_table="$(sed -n '/^### Shop VM LAN IPs/,/^###/p' "$DEVICE_SSOT" | grep '^|' | grep -v '^| VM\b' | grep -v '^|--')"

if [[ -z "$ssot_table" ]]; then
  err "could not extract Shop VM LAN IPs table from DEVICE_IDENTITY_SSOT.md"
  echo "D100 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "extracted SSOT table data"

# ── Check 4: Cross-reference each VM ──
while IFS=: read -r hostname ip; do
  [[ -z "$hostname" || -z "$ip" ]] && continue

  # Find matching row in SSOT table by canonical name (column 2, backtick-wrapped)
  ssot_row="$(echo "$ssot_table" | grep "\`${hostname}\`" || true)"

  if [[ -z "$ssot_row" ]]; then
    # Some VMs use different display names; try hostname as substring
    ssot_row="$(echo "$ssot_table" | grep -i "$hostname" || true)"
  fi

  if [[ -z "$ssot_row" ]]; then
    err "$hostname ($ip) — not found in DEVICE_IDENTITY_SSOT.md Shop VM table"
    CHECKED=$((CHECKED + 1))
    continue
  fi

  # Extract LAN IP from column 3 of the markdown table
  ssot_ip="$(echo "$ssot_row" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')"

  if [[ "$ssot_ip" == "$ip" ]]; then
    ok "$hostname: $ip matches SSOT"
  else
    err "$hostname: vm.lifecycle=$ip vs SSOT=$ssot_ip"
  fi
  CHECKED=$((CHECKED + 1))
done <<< "$lifecycle_data"

# ── Check 5: Home VMs parity ──
home_data="$(yq -r '.vms[] | select(.status == "active" and .proxmox_host == "proxmox-home" and .lan_ip != null) | "\(.hostname):\(.lan_ip)"' "$VM_LIFECYCLE" 2>/dev/null)"

if [[ -n "$home_data" ]]; then
  # Home VMs don't have a dedicated LAN IP table in DEVICE_IDENTITY_SSOT.md
  # but we can check against MINILAB_SSOT.md if it exists
  MINILAB_SSOT="$ROOT/docs/governance/MINILAB_SSOT.md"
  if [[ -f "$MINILAB_SSOT" ]]; then
    while IFS=: read -r hostname ip; do
      [[ -z "$hostname" || -z "$ip" ]] && continue
      # Check if the IP appears in MINILAB_SSOT near the hostname
      if grep -q "$ip" "$MINILAB_SSOT" 2>/dev/null; then
        ok "home/$hostname: $ip found in MINILAB_SSOT"
      else
        err "home/$hostname: $ip not found in MINILAB_SSOT.md"
      fi
      CHECKED=$((CHECKED + 1))
    done <<< "$home_data"
  fi
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D100 FAIL: $ERRORS check(s) failed ($CHECKED VMs checked)"
  exit 1
fi
echo "D100 PASS ($CHECKED VMs checked, all IPs match)"
exit 0
