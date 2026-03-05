#!/usr/bin/env bash
# TRIAGE: Verify inter-VLAN firewall/traffic rules from network.vlan.firewall.baseline.yaml are present on the UDR7. Fix by creating missing rules via UniFi traffic rules API or UI.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BASELINE="$ROOT/ops/bindings/network.vlan.firewall.baseline.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"

GATE_ID="D370"
PASS_COUNT=0
FAIL_COUNT=0

fail() {
  echo "${GATE_ID} FAIL: $*" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

command -v yq >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: yq" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: jq" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "${GATE_ID} FAIL: missing dependency: ssh" >&2; exit 1; }
[[ -f "$BASELINE" ]] || { echo "${GATE_ID} FAIL: missing baseline: $BASELINE" >&2; exit 1; }
[[ -f "$SSH_BINDING" ]] || { echo "${GATE_ID} FAIL: missing SSH binding: $SSH_BINDING" >&2; exit 1; }

# ── Contract status check ──
baseline_status="$(yq -r '.status // "unknown"' "$BASELINE")"
if [[ "$baseline_status" == "planned" ]]; then
  echo "${GATE_ID} SKIP: baseline status is planned (not yet active)" >&2
  exit 0
fi

# ── Resolve API key ──
UNIFI_HOME_API_KEY="${UNIFI_HOME_API_KEY:-}"
if [[ -z "$UNIFI_HOME_API_KEY" && -f "$INFISICAL_AGENT" ]]; then
  UNIFI_HOME_API_KEY="$("$INFISICAL_AGENT" get-cached home-assistant prod UNIFI_HOME_API_KEY 2>/dev/null || true)"
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

# ── Query live networks (build name→id map) ──
nets_json="$(
  ssh "${ssh_opts[@]}" "${PROXY_USER}@${PROXY_HOST}" "bash -s" <<EOF
api_key="\$(echo '$api_b64' | base64 -d)"
curl -sk -H "X-API-KEY: \$api_key" "https://${UDR_HOST}/proxy/network/api/s/default/rest/networkconf" 2>/dev/null
EOF
)" || {
  echo "${GATE_ID} SKIP: SSH to proxmox-home failed (network unreachable)" >&2
  exit 0
}

# ── Query live traffic rules ──
rules_json="$(
  ssh "${ssh_opts[@]}" "${PROXY_USER}@${PROXY_HOST}" "bash -s" <<EOF
api_key="\$(echo '$api_b64' | base64 -d)"
curl -sk -H "X-API-KEY: \$api_key" "https://${UDR_HOST}/proxy/network/v2/api/site/default/trafficrules" 2>/dev/null
EOF
)" || {
  echo "${GATE_ID} SKIP: SSH to proxmox-home failed for traffic rules" >&2
  exit 0
}

# Verify valid JSON
echo "$nets_json" | jq -e '.data' >/dev/null 2>&1 || {
  echo "${GATE_ID} SKIP: invalid response from UniFi networks API" >&2
  exit 0
}

# ── Build VLAN name → network ID map ──
# Map contract VLAN names to UniFi network IDs
default_id="$(echo "$nets_json" | jq -r '.data[] | select(.purpose == "corporate" and (.vlan_enabled | not)) | ._id' 2>/dev/null | head -1)"

resolve_net_id() {
  local vlan_name="$1"
  case "$vlan_name" in
    management)
      echo "$default_id"
      ;;
    *)
      # Capitalize first letter for UniFi name lookup
      local display_name
      display_name="$(echo "$vlan_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
      echo "$nets_json" | jq -r --arg name "$display_name" '.data[] | select(.name == $name) | ._id' 2>/dev/null | head -1
      ;;
  esac
}

# ── Check: rule_exists(action, src_vlan, dst_vlan) ──
rule_exists() {
  local action="$1" src_id="$2" dst_id="$3"
  local count
  count="$(echo "$rules_json" | jq -r --arg action "$action" --arg src "$src_id" --arg dst "$dst_id" \
    '[.[] | select(.action == $action and .enabled == true and (.target_devices[]?.network_id == $src) and (.network_ids[]? == $dst))] | length' 2>/dev/null || echo "0")"
  [[ "$count" -gt 0 ]]
}

# ── Check inter-VLAN rules from baseline ──
rule_count="$(yq -r '.inter_vlan_allow_rules | length' "$BASELINE")"

for i in $(seq 0 $((rule_count - 1))); do
  src_vlan="$(yq -r ".inter_vlan_allow_rules[$i].source_vlan" "$BASELINE")"
  dst_vlan="$(yq -r ".inter_vlan_allow_rules[$i].destination_vlan" "$BASELINE")"
  action="$(yq -r ".inter_vlan_allow_rules[$i].action" "$BASELINE")"
  desc="$(yq -r ".inter_vlan_allow_rules[$i].description" "$BASELINE")"

  # Handle multi-destination rules (comma-separated VLANs)
  if [[ "$dst_vlan" == *","* ]]; then
    IFS=',' read -ra dst_vlans <<< "$dst_vlan"
    for dv in "${dst_vlans[@]}"; do
      dv_clean="$(echo "$dv" | tr -d ' ')"
      src_id="$(resolve_net_id "$src_vlan")"
      dst_id="$(resolve_net_id "$dv_clean")"

      if [[ -z "$src_id" || -z "$dst_id" ]]; then
        fail "${desc}: network ID unresolvable (src=${src_vlan} dst=${dv_clean})"
        continue
      fi

      api_action="BLOCK"
      [[ "$action" == "ALLOW" ]] && api_action="ALLOW"

      if rule_exists "$api_action" "$src_id" "$dst_id"; then
        PASS_COUNT=$((PASS_COUNT + 1))
      else
        fail "${desc}: ${action} rule missing (${src_vlan} -> ${dv_clean})"
      fi
    done
  else
    src_id="$(resolve_net_id "$src_vlan")"
    dst_id="$(resolve_net_id "$dst_vlan")"

    if [[ -z "$src_id" || -z "$dst_id" ]]; then
      fail "${desc}: network ID unresolvable (src=${src_vlan} dst=${dst_vlan})"
      continue
    fi

    api_action="BLOCK"
    [[ "$action" == "ALLOW" ]] && api_action="ALLOW"

    if rule_exists "$api_action" "$src_id" "$dst_id"; then
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      fail "${desc}: ${action} rule missing (${src_vlan} -> ${dst_vlan})"
    fi
  fi
done

# ── Check: no disabled rules that should be enabled ──
disabled_count="$(echo "$rules_json" | jq '[.[] | select(.enabled == false)] | length' 2>/dev/null || echo "0")"
if [[ "$disabled_count" -gt 0 ]]; then
  fail "${disabled_count} disabled traffic rule(s) found (may indicate drift)"
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "${GATE_ID} FAIL: ${PASS_COUNT} pass, ${FAIL_COUNT} fail" >&2
  exit 1
fi

echo "${GATE_ID} PASS: ${PASS_COUNT} inter-VLAN rules verified against baseline"
