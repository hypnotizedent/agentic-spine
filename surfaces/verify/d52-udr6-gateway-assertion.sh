#!/usr/bin/env bash
# TRIAGE: Ensure shop SSOT docs reference correct gateway for UDR6 network.
# D52: UDR6 gateway assertion
# Validates that SSOT docs reference 192.168.1.1 as the shop gateway (UDR6),
# not the old T-Mobile direct (192.168.12.1) or Dell N2024P gateway.
#
# Why: The shop network cutover moves all infrastructure from 192.168.12.0/24
# to 192.168.1.0/24 behind the UDR6. If SSOT docs still reference the old
# subnet, agents will generate incorrect configs and verification commands.
#
# This gate is a documentation parity check (runs locally on SSOT files).
# The live SSH check (ssh pve 'ip route | grep default' | grep -q '192.168.1.1')
# is a post-cutover verification step, not a drift gate.
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0

# Check DEVICE_IDENTITY_SSOT.md has 192.168.1.0/24 shop subnet
DI="$SP/docs/governance/DEVICE_IDENTITY_SSOT.md"
if [[ -f "$DI" ]]; then
  if grep -q '192\.168\.1\.0/24.*Shop' "$DI"; then
    : # good
  else
    echo "FAIL: DEVICE_IDENTITY_SSOT.md missing 192.168.1.0/24 shop subnet" >&2
    ERRORS=$((ERRORS + 1))
  fi
  # Should NOT reference 192.168.12.0/24 as shop subnet (old)
  if grep -q '192\.168\.12\.0/24.*Shop' "$DI" 2>/dev/null; then
    echo "FAIL: DEVICE_IDENTITY_SSOT.md still references old 192.168.12.0/24 shop subnet" >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "FAIL: DEVICE_IDENTITY_SSOT.md not found" >&2
  ERRORS=$((ERRORS + 1))
fi

# Check SHOP_SERVER_SSOT.md has UDR6 gateway
SS="$SP/docs/governance/SHOP_SERVER_SSOT.md"
if [[ -f "$SS" ]]; then
  if grep -q '192\.168\.1\.1' "$SS"; then
    : # good
  else
    echo "FAIL: SHOP_SERVER_SSOT.md missing 192.168.1.1 gateway reference" >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "FAIL: SHOP_SERVER_SSOT.md not found" >&2
  ERRORS=$((ERRORS + 1))
fi

# Check NETWORK_POLICIES.md has updated shop subnet
NP="$SP/docs/governance/NETWORK_POLICIES.md"
if [[ -f "$NP" ]]; then
  if grep -q '192\.168\.1\.0/24' "$NP"; then
    : # good
  else
    echo "FAIL: NETWORK_POLICIES.md missing 192.168.1.0/24 shop subnet" >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "FAIL: NETWORK_POLICIES.md not found" >&2
  ERRORS=$((ERRORS + 1))
fi

# Check that DEVICE_IDENTITY_SSOT.md uses VMID-based LAN IPs (not Tailscale-derived)
if [[ -f "$DI" ]]; then
  # infra-core must be .204 (VMID), not .128 (Tailscale-derived)
  if grep -q '192\.168\.1\.128.*204' "$DI" 2>/dev/null; then
    echo "FAIL: DEVICE_IDENTITY_SSOT.md has Tailscale-derived IP .128 for infra-core (should be .204)" >&2
    ERRORS=$((ERRORS + 1))
  fi
  # download-stack must be .209 (VMID), not .76 (Tailscale-derived)
  if grep -q '192\.168\.1\.76.*209' "$DI" 2>/dev/null; then
    echo "FAIL: DEVICE_IDENTITY_SSOT.md has Tailscale-derived IP .76 for download-stack (should be .209)" >&2
    ERRORS=$((ERRORS + 1))
  fi
  # streaming-stack must be .210 (VMID), not .64 (Tailscale-derived)
  if grep -q '192\.168\.1\.64.*210' "$DI" 2>/dev/null; then
    echo "FAIL: DEVICE_IDENTITY_SSOT.md has Tailscale-derived IP .64 for streaming-stack (should be .210)" >&2
    ERRORS=$((ERRORS + 1))
  fi
fi

[[ "$ERRORS" -eq 0 ]] && exit 0 || exit 1
