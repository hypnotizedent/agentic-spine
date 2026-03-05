#!/usr/bin/env bash
# TRIAGE: Sync tailscale.tailnet.snapshot.yaml with ssh.targets.yaml for IP and access_policy parity.
# D310: Tailnet snapshot parity lock.
# Enforces: tailnet snapshot <-> ssh.targets IP and access_policy parity for spine-governed devices.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SNAPSHOT="$ROOT/ops/bindings/tailscale.tailnet.snapshot.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"

fail=0
err() { echo "D310 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D310 FAIL: missing dependency: yq" >&2; exit 1; }
[[ -f "$SNAPSHOT" ]] || { echo "D310 FAIL: missing tailnet snapshot: $SNAPSHOT" >&2; exit 1; }
[[ -f "$SSH_BINDING" ]] || { echo "D310 FAIL: missing ssh binding: $SSH_BINDING" >&2; exit 1; }

# Structural: snapshot must have devices array and tailnet field
tailnet="$(yq e -r '.tailnet // ""' "$SNAPSHOT" 2>/dev/null || true)"
[[ -n "$tailnet" && "$tailnet" != "null" ]] || err "snapshot missing tailnet field"

dev_count="$(yq e '.devices | length' "$SNAPSHOT" 2>/dev/null || echo 0)"
[[ "$dev_count" =~ ^[0-9]+$ && "$dev_count" -gt 0 ]] || { echo "D310 FAIL: snapshot has no devices" >&2; exit 1; }

checked=0
for ((i=0; i<dev_count; i++)); do
  snap_id="$(yq e -r ".devices[$i].id // \"\"" "$SNAPSHOT")"
  snap_policy="$(yq e -r ".devices[$i].access_policy // \"\"" "$SNAPSHOT")"

  # Skip client devices (not in ssh.targets)
  [[ "$snap_policy" == "client" ]] && continue

  snap_ts_ip="$(yq e -r ".devices[$i].tailscale_ip // \"\"" "$SNAPSHOT")"
  snap_lan_ip="$(yq e -r ".devices[$i].lan_ip // \"\"" "$SNAPSHOT")"

  # Look up in ssh.targets
  ssh_host="$(yq e -r ".ssh.targets[] | select(.id == \"$snap_id\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  [[ -n "$ssh_host" && "$ssh_host" != "null" ]] || continue  # device not in ssh.targets (e.g. homeassistant via ha alias)

  checked=$((checked + 1))
  ssh_ts_ip="$(yq e -r ".ssh.targets[] | select(.id == \"$snap_id\") | .tailscale_ip // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  ssh_policy="$(yq e -r ".ssh.targets[] | select(.id == \"$snap_id\") | .access_policy // \"\"" "$SSH_BINDING" 2>/dev/null || true)"

  # Tailscale IP parity
  if [[ -n "$snap_ts_ip" && "$snap_ts_ip" != "null" && -n "$ssh_ts_ip" && "$ssh_ts_ip" != "null" ]]; then
    [[ "$snap_ts_ip" == "$ssh_ts_ip" ]] || err "$snap_id: tailscale_ip mismatch snapshot=$snap_ts_ip ssh.targets=$ssh_ts_ip"
  fi

  # LAN IP parity (for lan_first devices, ssh.targets.host should match snapshot lan_ip)
  if [[ "$snap_policy" == "lan_first" && -n "$snap_lan_ip" && "$snap_lan_ip" != "null" ]]; then
    [[ "$ssh_host" == "$snap_lan_ip" ]] || err "$snap_id: LAN IP mismatch snapshot=$snap_lan_ip ssh.targets.host=$ssh_host"
  fi

  # Access policy parity
  if [[ -n "$snap_policy" && "$snap_policy" != "null" && -n "$ssh_policy" && "$ssh_policy" != "null" ]]; then
    [[ "$snap_policy" == "$ssh_policy" ]] || err "$snap_id: access_policy mismatch snapshot=$snap_policy ssh.targets=$ssh_policy"
  fi
done

[[ "$checked" -gt 0 ]] || err "no spine-governed devices checked for parity"

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D310 PASS: tailnet snapshot parity valid (checked=$checked devices)"
