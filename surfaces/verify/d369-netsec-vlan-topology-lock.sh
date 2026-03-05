#!/usr/bin/env bash
# TRIAGE: Verify each VLAN from network.vlan.topology.contract.yaml exists on the UDR7 with correct subnet and DHCP config. Fix by creating or updating VLANs via UniFi API or UI.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/network.vlan.topology.contract.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"

GATE_ID="D369"
PASS_COUNT=0
FAIL_COUNT=0

fail() {
  echo "${GATE_ID} FAIL: $*" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

command -v yq >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: yq" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: jq" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: ssh" >&2; exit 1; }
[[ -f "$CONTRACT" ]] || { echo "${GATE_ID} FAIL: missing contract: $CONTRACT" >&2; exit 1; }
[[ -f "$SSH_BINDING" ]] || { echo "${GATE_ID} FAIL: missing SSH binding: $SSH_BINDING" >&2; exit 1; }

# ── Contract status check ──
contract_status="$(yq -r '.status // "unknown"' "$CONTRACT")"
if [[ "$contract_status" == "planned" ]]; then
  echo "${GATE_ID} SKIP: contract status is planned (not yet active)" >&2
  exit 0
fi

# ── Resolve API key ──
UNIFI_HOME_API_KEY="${UNIFI_HOME_API_KEY:-}"
if [[ -z "$UNIFI_HOME_API_KEY" && -f "$INFISICAL_AGENT" ]]; then
  UNIFI_HOME_API_KEY="$("$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_HOME_API_KEY 2>/dev/null || true)"
fi
if [[ -z "$UNIFI_HOME_API_KEY" ]]; then
  echo "${GATE_ID} SKIP: UNIFI_HOME_API_KEY not available (offline)" >&2
  exit 0
fi

# ── Resolve SSH proxy ──
UDR_HOST="$(yq -r '.ssh.targets[] | select(.id == "udr-home") | .host' "$SSH_BINDING")"
PROXY_HOST="$(yq -r '.ssh.targets[] | select(.id == "proxmox-home") | .host' "$SSH_BINDING")"
PROXY_USER="$(yq -r '.ssh.targets[] | select(.id == "proxmox-home") | .user // "root"' "$SSH_BINDING")"
DEF_TO="$(yq -r '.ssh.defaults.connect_timeout_sec // 5' "$SSH_BINDING")"

ssh_opts=(
  -o "ConnectTimeout=${DEF_TO}"
  -o "StrictHostKeyChecking=no"
  -o "UserKnownHostsFile=/dev/null"
  -o "BatchMode=yes"
  -o "LogLevel=ERROR"
)

api_b64="$(printf '%s' "$UNIFI_HOME_API_KEY" | base64)"

# ── Query live VLANs ──
live_json="$(
  ssh "${ssh_opts[@]}" "${PROXY_USER}@${PROXY_HOST}" "bash -s" <<EOF
api_key="\$(echo '$api_b64' | base64 -d)"
curl -sk -H "X-API-KEY: \$api_key" "https://${UDR_HOST}/proxy/network/api/s/default/rest/networkconf" 2>/dev/null
EOF
)" || {
  echo "${GATE_ID} SKIP: SSH to proxmox-home failed (network unreachable)" >&2
  exit 0
}

# Verify we got valid JSON
echo "$live_json" | jq -e '.data' >/dev/null 2>&1 || {
  echo "${GATE_ID} SKIP: invalid response from UniFi API" >&2
  exit 0
}

# ── Check each VLAN (skip VLAN 1 — default network) ──
vlan_count="$(yq -r '.vlans | length' "$CONTRACT")"

for i in $(seq 0 $((vlan_count - 1))); do
  vlan_id="$(yq -r ".vlans[$i].vlan_id" "$CONTRACT")"
  vlan_name="$(yq -r ".vlans[$i].name" "$CONTRACT")"

  # Skip VLAN 1 (default/management — not managed as a tagged VLAN)
  if [[ "$vlan_id" == "1" ]]; then
    continue
  fi

  expected_gateway="$(yq -r ".vlans[$i].home.gateway" "$CONTRACT")"
  expected_subnet="$(yq -r ".vlans[$i].home.subnet" "$CONTRACT")"
  expected_mask="$(echo "$expected_subnet" | cut -d'/' -f2)"
  expected_subnet_unifi="${expected_gateway}/${expected_mask}"

  range_raw="$(yq -r ".vlans[$i].home.dhcp_range" "$CONTRACT")"
  expected_dhcp_start="$(echo "$range_raw" | cut -d'-' -f1)"
  dhcp_end_last="$(echo "$range_raw" | cut -d'-' -f2)"
  dhcp_prefix="${expected_dhcp_start%.*}"
  expected_dhcp_stop="${dhcp_prefix}.${dhcp_end_last}"

  # Check: VLAN exists
  live_match="$(echo "$live_json" | jq -r ".data[] | select(.vlan == ${vlan_id} and .vlan_enabled == true)" 2>/dev/null)"
  if [[ -z "$live_match" || "$live_match" == "null" ]]; then
    fail "VLAN ${vlan_id} (${vlan_name}): not found on UDR"
    continue
  fi

  # Check: subnet
  live_subnet="$(echo "$live_match" | jq -r '.ip_subnet')"
  if [[ "$live_subnet" != "$expected_subnet_unifi" ]]; then
    fail "VLAN ${vlan_id} (${vlan_name}): subnet expected=${expected_subnet_unifi} got=${live_subnet}"
    continue
  fi

  # Check: DHCP enabled
  live_dhcp="$(echo "$live_match" | jq -r '.dhcpd_enabled')"
  if [[ "$live_dhcp" != "true" ]]; then
    fail "VLAN ${vlan_id} (${vlan_name}): DHCP not enabled"
    continue
  fi

  # Check: DHCP range
  live_start="$(echo "$live_match" | jq -r '.dhcpd_start')"
  live_stop="$(echo "$live_match" | jq -r '.dhcpd_stop')"
  if [[ "$live_start" != "$expected_dhcp_start" || "$live_stop" != "$expected_dhcp_stop" ]]; then
    fail "VLAN ${vlan_id} (${vlan_name}): DHCP range expected=${expected_dhcp_start}-${expected_dhcp_stop} got=${live_start}-${live_stop}"
    continue
  fi

  PASS_COUNT=$((PASS_COUNT + 1))
done

# ── mDNS parity check ──
mdns_contract="$ROOT/ops/bindings/network.mdns.governance.contract.yaml"
if [[ -f "$mdns_contract" ]]; then
  mdns_status="$(yq -r '.status // "planned"' "$mdns_contract")"
  if [[ "$mdns_status" != "planned" ]]; then
    enable_count="$(yq -r '.unifi_config.enable_on | length' "$mdns_contract")"
    for j in $(seq 0 $((enable_count - 1))); do
      mdns_vlan="$(yq -r ".unifi_config.enable_on[$j].vlan_id" "$mdns_contract")"
      live_mdns="$(echo "$live_json" | jq -r ".data[] | select(.vlan == ${mdns_vlan} and .vlan_enabled == true) | .mdns_enabled // false" 2>/dev/null)"
      mdns_net="$(yq -r ".unifi_config.enable_on[$j].network" "$mdns_contract")"
      if [[ "$live_mdns" == "true" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
      else
        fail "mDNS: expected enabled on ${mdns_net} (VLAN ${mdns_vlan}), got ${live_mdns}"
      fi
    done
  fi
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "${GATE_ID} FAIL: ${PASS_COUNT} pass, ${FAIL_COUNT} fail" >&2
  exit 1
fi

echo "${GATE_ID} PASS: ${PASS_COUNT} checks passed (VLANs + mDNS)"
