#!/usr/bin/env bash
# unifi-home-agent.sh — CLI agent for home UniFi OS API
#
# Queries the UDR7 UniFi controller API through proxmox-home (LAN-only device).
# Mirrors unifi-agent.sh (shop) for home network.
#
# Commands:
#   auth                                       Test authentication (no secrets printed)
#   clients [--site S] [--json]                List connected clients (MAC/IP/name)
#   reservations [--site S] [--json]           List DHCP reservations
#   wifi-list [--site S] [--json]              List configured WLANs
#   wifi-create --name N --passphrase P --band B [--site S]  Create WLAN
#   reservation-create --mac M --ip I --name N [--site S]    Create DHCP reservation
#
# Credential resolution:
#   1. UNIFI_HOME_USER / UNIFI_HOME_PASSWORD env vars (cookie auth)
#   2. UNIFI_HOME_API_KEY env var (X-API-KEY auth — preferred for mutating commands)
#   3. Infisical via infisical-agent.sh get-cached (home-assistant project)
#
# Host: reads udr-home from ssh.targets.yaml (default 10.0.0.1)
# API calls are proxied through proxmox-home via SSH (UDR7 is LAN-only).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SSH_BINDING="$SPINE_ROOT/ops/bindings/ssh.targets.yaml"
INFISICAL_AGENT="$SPINE_ROOT/ops/tools/infisical-agent.sh"

stop(){ echo "STOP (2): $*" >&2; exit 2; }

command -v yq >/dev/null 2>&1 || stop "missing dependency: yq"
command -v jq >/dev/null 2>&1 || stop "missing dependency: jq"
command -v ssh >/dev/null 2>&1 || stop "missing dependency: ssh"
[[ -f "$SSH_BINDING" ]] || stop "missing binding: $SSH_BINDING"

# ── Resolve UDR host from ssh.targets.yaml ──
UDR_HOST="$(yq -r '.ssh.targets[] | select(.id == "udr-home") | .host' "$SSH_BINDING")"
[[ -n "$UDR_HOST" && "$UDR_HOST" != "null" ]] || stop "udr-home not found in ssh.targets.yaml"

# ── Resolve proxmox-home probe host ──
PROXY_HOST="$(yq -r '.ssh.targets[] | select(.id == "proxmox-home") | .host' "$SSH_BINDING")"
PROXY_USER="$(yq -r '.ssh.targets[] | select(.id == "proxmox-home") | .user // "root"' "$SSH_BINDING")"
[[ -n "$PROXY_HOST" && "$PROXY_HOST" != "null" ]] || stop "proxmox-home not found in ssh.targets.yaml"

# SSH options
DEF_STRICT="$(yq -r '.ssh.defaults.strict_host_key_checking // "no"' "$SSH_BINDING")"
DEF_KNOWN_HOSTS="$(yq -r '.ssh.defaults.user_known_hosts_file // "/dev/null"' "$SSH_BINDING")"
DEF_TO="$(yq -r '.ssh.defaults.connect_timeout_sec // 5' "$SSH_BINDING")"

ssh_opts=(
  -o "ConnectTimeout=${DEF_TO}"
  -o "StrictHostKeyChecking=${DEF_STRICT}"
  -o "UserKnownHostsFile=${DEF_KNOWN_HOSTS}"
  -o "BatchMode=yes"
  -o "LogLevel=ERROR"
)

# ── Resolve credentials ──
resolve_creds() {
  if [[ -n "${UNIFI_HOME_USER:-}" && -n "${UNIFI_HOME_PASSWORD:-}" ]]; then
    return 0
  fi

  if [[ -f "$INFISICAL_AGENT" ]]; then
    UNIFI_HOME_USER="$("$INFISICAL_AGENT" get-cached home-assistant prod UNIFI_HOME_USER 2>/dev/null || true)"
    UNIFI_HOME_PASSWORD="$("$INFISICAL_AGENT" get-cached home-assistant prod UNIFI_HOME_PASSWORD 2>/dev/null || true)"
  fi

  if [[ -z "${UNIFI_HOME_USER:-}" || -z "${UNIFI_HOME_PASSWORD:-}" ]]; then
    return 1
  fi
  return 0
}

# ── Resolve API key (X-API-KEY auth — preferred for mutating commands) ──
resolve_api_key() {
  if [[ -n "${UNIFI_HOME_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ -f "$INFISICAL_AGENT" ]]; then
    UNIFI_HOME_API_KEY="$("$INFISICAL_AGENT" get-cached home-assistant prod UNIFI_HOME_API_KEY 2>/dev/null || true)"
  fi

  if [[ -z "${UNIFI_HOME_API_KEY:-}" ]]; then
    return 1
  fi
  return 0
}

# ── Run a script on proxmox-home via SSH (stdin) ──
proxy_run() {
  ssh "${ssh_opts[@]}" "${PROXY_USER}@${PROXY_HOST}" "bash -s"
}

# ── Auth command ──
cmd_auth() {
  if ! resolve_creds; then
    echo "FAIL: UniFi home credentials not available"
    echo "hint: set UNIFI_HOME_USER + UNIFI_HOME_PASSWORD env vars"
    echo "  or: store in Infisical home-assistant/prod"
    exit 1
  fi

  echo "unifi-home-agent: auth"
  echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"

  local udr_b64 user_b64 pass_b64
  udr_b64="$(printf '%s' "$UDR_HOST" | base64)"
  user_b64="$(printf '%s' "$UNIFI_HOME_USER" | base64)"
  pass_b64="$(printf '%s' "$UNIFI_HOME_PASSWORD" | base64)"

  local auth_result
  auth_result="$(
    proxy_run <<EOF
set -euo pipefail

udr="\$(echo '$udr_b64' | base64 -d)"
user="\$(echo '$user_b64' | base64 -d)"
pass="\$(echo '$pass_b64' | base64 -d)"

payload="\$(UNIFI_USER="\$user" UNIFI_PASS="\$pass" python3 - <<'PY'
import json, os
print(json.dumps({"username": os.environ["UNIFI_USER"], "password": os.environ["UNIFI_PASS"]}))
PY
)"

http_code="\$(printf '%s' "\$payload" | curl -sk -X POST "https://\${udr}/api/auth/login" \
  -H "Content-Type: application/json" \
  --data-binary @- \
  -c /tmp/unifi_home_cookies.txt \
  -w '%{http_code}' -o /dev/null 2>/dev/null || true)"

rm -f /tmp/unifi_home_cookies.txt
echo "\$http_code"
EOF
  )" || true

  if [[ "$auth_result" == "200" ]]; then
    echo "status: OK (authenticated)"
  else
    echo "status: FAIL (HTTP $auth_result)"
    exit 1
  fi
}

# ── Clients command ──
cmd_clients() {
  local site="default"
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --site) site="${2:-default}"; shift 2 ;;
      --json) json_mode=1; shift ;;
      *) shift ;;
    esac
  done

  if ! resolve_creds; then
    echo "FAIL: UniFi home credentials not available" >&2
    exit 1
  fi

  local udr_b64 site_b64 user_b64 pass_b64
  udr_b64="$(printf '%s' "$UDR_HOST" | base64)"
  site_b64="$(printf '%s' "$site" | base64)"
  user_b64="$(printf '%s' "$UNIFI_HOME_USER" | base64)"
  pass_b64="$(printf '%s' "$UNIFI_HOME_PASSWORD" | base64)"

  local raw
  raw="$(
    proxy_run <<EOF
set -euo pipefail

udr="\$(echo '$udr_b64' | base64 -d)"
site="\$(echo '$site_b64' | base64 -d)"
user="\$(echo '$user_b64' | base64 -d)"
pass="\$(echo '$pass_b64' | base64 -d)"

payload="\$(UNIFI_USER="\$user" UNIFI_PASS="\$pass" python3 - <<'PY'
import json, os
print(json.dumps({"username": os.environ["UNIFI_USER"], "password": os.environ["UNIFI_PASS"]}))
PY
)"

# Auth (cookie)
printf '%s' "\$payload" | curl -sk -X POST "https://\${udr}/api/auth/login" \
  -H "Content-Type: application/json" \
  --data-binary @- \
  -c /tmp/unifi_home_cookies.txt \
  -o /dev/null 2>/dev/null

# Query clients
curl -sk "https://\${udr}/proxy/network/api/s/\${site}/stat/sta" -b /tmp/unifi_home_cookies.txt 2>/dev/null

rm -f /tmp/unifi_home_cookies.txt
EOF
  )" || {
    echo "FAIL: could not query UniFi API via proxmox-home" >&2
    exit 1
  }

  if [[ "$json_mode" -eq 1 ]]; then
    echo "$raw" | jq -r '[.data[] | {mac, ip, hostname: (.hostname // .name // "unknown"), name: (.name // .hostname // "unknown"), is_wired, last_seen}]' 2>/dev/null || {
      echo "FAIL: could not parse UniFi response" >&2
      echo "$raw" >&2
      exit 1
    }
  else
    echo "unifi-home-agent: clients (site=$site)"
    echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"
    echo
    { printf 'MAC\tIP\tNAME\tTYPE\n'; echo "$raw" | jq -r '.data[] | "\(.mac)\t\(.ip // "n/a")\t\(.hostname // .name // "unknown")\t\(if .is_wired then "wired" else "wireless" end)"' 2>/dev/null \
      | sort -t$'\t' -k2,2V; } \
      | column -t -s$'\t' 2>/dev/null \
      || {
        echo "FAIL: could not parse UniFi response" >&2
        echo "$raw" >&2
        exit 1
      }
  fi
}

# ── Reservations command ──
cmd_reservations() {
  local site="default"
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --site) site="${2:-default}"; shift 2 ;;
      --json) json_mode=1; shift ;;
      *) shift ;;
    esac
  done

  if ! resolve_creds; then
    echo "FAIL: UniFi home credentials not available" >&2
    exit 1
  fi

  local udr_b64 site_b64 user_b64 pass_b64
  udr_b64="$(printf '%s' "$UDR_HOST" | base64)"
  site_b64="$(printf '%s' "$site" | base64)"
  user_b64="$(printf '%s' "$UNIFI_HOME_USER" | base64)"
  pass_b64="$(printf '%s' "$UNIFI_HOME_PASSWORD" | base64)"

  local raw
  raw="$(
    proxy_run <<EOF
set -euo pipefail

udr="\$(echo '$udr_b64' | base64 -d)"
site="\$(echo '$site_b64' | base64 -d)"
user="\$(echo '$user_b64' | base64 -d)"
pass="\$(echo '$pass_b64' | base64 -d)"

payload="\$(UNIFI_USER="\$user" UNIFI_PASS="\$pass" python3 - <<'PY'
import json, os
print(json.dumps({"username": os.environ["UNIFI_USER"], "password": os.environ["UNIFI_PASS"]}))
PY
)"

# Auth (cookie)
printf '%s' "\$payload" | curl -sk -X POST "https://\${udr}/api/auth/login" \
  -H "Content-Type: application/json" \
  --data-binary @- \
  -c /tmp/unifi_home_cookies.txt \
  -o /dev/null 2>/dev/null

# Query users with fixed IPs (DHCP reservations)
curl -sk "https://\${udr}/proxy/network/api/s/\${site}/rest/user" -b /tmp/unifi_home_cookies.txt 2>/dev/null

rm -f /tmp/unifi_home_cookies.txt
EOF
  )" || {
    echo "FAIL: could not query UniFi API via proxmox-home" >&2
    exit 1
  }

  if [[ "$json_mode" -eq 1 ]]; then
    echo "$raw" | jq -r '[.data[] | select(.use_fixedip == true) | {mac, ip: .fixed_ip, name: (.name // .hostname // "unknown"), noted: (.noted // false)}]' 2>/dev/null || {
      echo "FAIL: could not parse UniFi response" >&2
      echo "$raw" >&2
      exit 1
    }
  else
    echo "unifi-home-agent: reservations (site=$site)"
    echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"
    echo
    { printf 'MAC\tIP\tNAME\n'; echo "$raw" | jq -r '.data[] | select(.use_fixedip == true) | "\(.mac)\t\(.fixed_ip)\t\(.name // .hostname // "unknown")"' 2>/dev/null \
      | sort -t$'\t' -k2,2V; } \
      | column -t -s$'\t' 2>/dev/null \
      || {
        echo "FAIL: could not parse UniFi response" >&2
        echo "$raw" >&2
        exit 1
      }
  fi
}

# ── WiFi List command (X-API-KEY auth) ──
cmd_wifi_list() {
  local site="default"
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --site) site="${2:-default}"; shift 2 ;;
      --json) json_mode=1; shift ;;
      *) shift ;;
    esac
  done

  if ! resolve_api_key; then
    echo "FAIL: UNIFI_HOME_API_KEY not available" >&2
    echo "hint: set UNIFI_HOME_API_KEY env var or store in Infisical home-assistant/prod" >&2
    exit 1
  fi

  local api_b64
  api_b64="$(printf '%s' "$UNIFI_HOME_API_KEY" | base64)"

  local raw
  raw="$(
    proxy_run <<EOF
set -euo pipefail
api_key="\$(echo '$api_b64' | base64 -d)"
curl -sk "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/wlanconf" \
  -H "X-API-KEY: \$api_key" \
  -H "Accept: application/json" 2>/dev/null
EOF
  )" || {
    echo "FAIL: could not query UniFi WLAN API via proxmox-home" >&2
    exit 1
  }

  if [[ "$json_mode" -eq 1 ]]; then
    echo "$raw" | jq -r '[.data[] | {name, enabled, wlan_band, security, is_guest}]' 2>/dev/null || {
      echo "FAIL: could not parse UniFi response" >&2
      echo "$raw" >&2
      exit 1
    }
  else
    echo "unifi-home-agent: wifi-list (site=$site)"
    echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"
    echo
    { printf 'SSID\tBAND\tENABLED\tSECURITY\n'; echo "$raw" | jq -r '.data[] | "\(.name)\t\(.wlan_band // "both")\t\(.enabled)\t\(.security // "open")"' 2>/dev/null; } \
      | column -t -s$'\t' 2>/dev/null \
      || {
        echo "FAIL: could not parse UniFi response" >&2
        echo "$raw" >&2
        exit 1
      }
  fi
}

# ── WiFi Create command (X-API-KEY auth, mutating) ──
cmd_wifi_create() {
  local site="default"
  local name="" passphrase="" band=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --site) site="${2:-default}"; shift 2 ;;
      --name) name="${2:-}"; shift 2 ;;
      --passphrase) passphrase="${2:-}"; shift 2 ;;
      --band) band="${2:-}"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  [[ -n "$name" ]] || { echo "FAIL: --name is required" >&2; exit 1; }
  [[ -n "$passphrase" ]] || { echo "FAIL: --passphrase is required" >&2; exit 1; }
  [[ -n "$band" ]] || { echo "FAIL: --band is required (2g|5g|both)" >&2; exit 1; }
  [[ "$band" =~ ^(2g|5g|both)$ ]] || { echo "FAIL: --band must be 2g, 5g, or both" >&2; exit 1; }

  if ! resolve_api_key; then
    echo "FAIL: UNIFI_HOME_API_KEY not available" >&2
    exit 1
  fi

  local api_b64 name_b64 pass_b64
  api_b64="$(printf '%s' "$UNIFI_HOME_API_KEY" | base64)"
  name_b64="$(printf '%s' "$name" | base64)"
  pass_b64="$(printf '%s' "$passphrase" | base64)"

  echo "unifi-home-agent: wifi-create"
  echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"
  echo "creating WLAN: name=$name band=$band"
  echo

  # Step 1: Get networkconf_id from existing WLANs
  local wlan_data
  wlan_data="$(
    proxy_run <<EOF
set -euo pipefail
api_key="\$(echo '$api_b64' | base64 -d)"
curl -sk "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/wlanconf" \
  -H "X-API-KEY: \$api_key" \
  -H "Accept: application/json" 2>/dev/null
EOF
  )" || {
    echo "FAIL: could not query existing WLANs" >&2
    exit 1
  }

  local networkconf_id ap_group_ids
  networkconf_id="$(echo "$wlan_data" | jq -r '.data[0].networkconf_id // empty' 2>/dev/null)"
  ap_group_ids="$(echo "$wlan_data" | jq -c '.data[0].ap_group_ids // []' 2>/dev/null)"
  if [[ -z "$networkconf_id" ]]; then
    echo "FAIL: could not determine networkconf_id from existing WLANs" >&2
    exit 1
  fi
  echo "networkconf_id: $networkconf_id (from existing WLAN)"

  local ap_groups_b64
  ap_groups_b64="$(printf '%s' "$ap_group_ids" | base64)"

  # Step 2: Create the new WLAN
  local result
  result="$(
    proxy_run <<EOF
set -euo pipefail
api_key="\$(echo '$api_b64' | base64 -d)"
wlan_name="\$(echo '$name_b64' | base64 -d)"
wlan_pass="\$(echo '$pass_b64' | base64 -d)"
ap_groups="\$(echo '$ap_groups_b64' | base64 -d)"

payload="\$(WLAN_NAME="\$wlan_name" WLAN_PASS="\$wlan_pass" WLAN_BAND="$band" NET_ID="$networkconf_id" AP_GROUPS="\$ap_groups" python3 - <<'PY'
import json, os
data = {
    "name": os.environ["WLAN_NAME"],
    "enabled": True,
    "security": "wpapsk",
    "wpa_mode": "wpa2",
    "x_passphrase": os.environ["WLAN_PASS"],
    "wlan_band": os.environ["WLAN_BAND"],
    "networkconf_id": os.environ["NET_ID"],
    "ap_group_ids": json.loads(os.environ["AP_GROUPS"]),
    "ap_group_mode": "all"
}
print(json.dumps(data))
PY
)"

http_code="\$(printf '%s' "\$payload" | curl -sk -X POST "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/wlanconf" \
  -H "X-API-KEY: \$api_key" \
  -H "Content-Type: application/json" \
  --data-binary @- \
  -w '\n%{http_code}' 2>/dev/null)"

echo "\$http_code"
EOF
  )" || {
    echo "FAIL: could not create WLAN via proxmox-home" >&2
    exit 1
  }

  # Parse response: last line is HTTP code, everything before is body
  local http_code body
  http_code="$(echo "$result" | tail -1)"
  body="$(echo "$result" | sed '$d')"

  if [[ "$http_code" == "200" ]]; then
    echo "OK: WLAN '$name' created (HTTP 200)"
    echo "$body" | jq -r '.data[] | "  id: \(._id)\n  name: \(.name)\n  band: \(.wlan_band)\n  enabled: \(.enabled)"' 2>/dev/null || true
  else
    echo "FAIL: HTTP $http_code"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
  fi
}

# ── Reservation Create command (X-API-KEY auth, mutating) ──
cmd_reservation_create() {
  local site="default"
  local mac="" ip="" name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --site) site="${2:-default}"; shift 2 ;;
      --mac) mac="${2:-}"; shift 2 ;;
      --ip) ip="${2:-}"; shift 2 ;;
      --name) name="${2:-}"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  [[ -n "$mac" ]] || { echo "FAIL: --mac is required" >&2; exit 1; }
  [[ -n "$ip" ]] || { echo "FAIL: --ip is required" >&2; exit 1; }
  [[ -n "$name" ]] || { echo "FAIL: --name is required" >&2; exit 1; }

  # Validate MAC format (xx:xx:xx:xx:xx:xx)
  if ! echo "$mac" | grep -qE '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$'; then
    echo "FAIL: invalid MAC format (expected xx:xx:xx:xx:xx:xx)" >&2
    exit 1
  fi

  # Validate IP is in 10.0.0.x subnet
  if ! echo "$ip" | grep -qE '^10\.0\.0\.[0-9]{1,3}$'; then
    echo "FAIL: IP must be in 10.0.0.0/24 subnet" >&2
    exit 1
  fi

  if ! resolve_api_key; then
    echo "FAIL: UNIFI_HOME_API_KEY not available" >&2
    exit 1
  fi

  # Lowercase MAC for UniFi
  mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"

  local api_b64 mac_b64 ip_b64 name_b64
  api_b64="$(printf '%s' "$UNIFI_HOME_API_KEY" | base64)"
  mac_b64="$(printf '%s' "$mac" | base64)"
  ip_b64="$(printf '%s' "$ip" | base64)"
  name_b64="$(printf '%s' "$name" | base64)"

  echo "unifi-home-agent: reservation-create"
  echo "host: $UDR_HOST (via proxmox-home $PROXY_HOST)"
  echo "creating reservation: mac=$mac ip=$ip name=$name"
  echo

  local result
  result="$(
    proxy_run <<EOF
set -euo pipefail
api_key="\$(echo '$api_b64' | base64 -d)"
dev_mac="\$(echo '$mac_b64' | base64 -d)"
dev_ip="\$(echo '$ip_b64' | base64 -d)"
dev_name="\$(echo '$name_b64' | base64 -d)"

payload="\$(DEV_MAC="\$dev_mac" DEV_IP="\$dev_ip" DEV_NAME="\$dev_name" python3 - <<'PY'
import json, os
data = {
    "mac": os.environ["DEV_MAC"],
    "name": os.environ["DEV_NAME"],
    "use_fixedip": True,
    "fixed_ip": os.environ["DEV_IP"],
    "noted": True
}
print(json.dumps(data))
PY
)"

# Try POST first; if MacUsed, find existing user _id and PUT instead
http_code="\$(printf '%s' "\$payload" | curl -sk -X POST "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/user" \
  -H "X-API-KEY: \$api_key" \
  -H "Content-Type: application/json" \
  --data-binary @- \
  -w '\n%{http_code}' 2>/dev/null)"

body="\$(echo "\$http_code" | sed '\$d')"
code="\$(echo "\$http_code" | tail -1)"

if echo "\$body" | grep -q 'MacUsed'; then
  # Device exists — find _id and PUT to update
  user_id="\$(curl -sk "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/user" \
    -H "X-API-KEY: \$api_key" \
    -H "Accept: application/json" 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(next(u['_id'] for u in d['data'] if u['mac']=='\$dev_mac'))" 2>/dev/null)"

  if [[ -n "\$user_id" ]]; then
    update_payload="\$(DEV_NAME="\$dev_name" DEV_IP="\$dev_ip" python3 - <<'PY2'
import json, os
print(json.dumps({"name": os.environ["DEV_NAME"], "use_fixedip": True, "fixed_ip": os.environ["DEV_IP"], "noted": True}))
PY2
)"
    http_code="\$(printf '%s' "\$update_payload" | curl -sk -X PUT "https://${UDR_HOST}/proxy/network/api/s/${site}/rest/user/\$user_id" \
      -H "X-API-KEY: \$api_key" \
      -H "Content-Type: application/json" \
      --data-binary @- \
      -w '\n%{http_code}' 2>/dev/null)"
    echo "PUT_UPDATE"
    echo "\$http_code"
  else
    echo "\$code"
    echo "\$body"
  fi
else
  echo "\$http_code"
fi
EOF
  )" || {
    echo "FAIL: could not create reservation via proxmox-home" >&2
    exit 1
  }

  local http_code body method="POST"
  if echo "$result" | head -1 | grep -q 'PUT_UPDATE'; then
    method="PUT"
    result="$(echo "$result" | tail -n +2)"
  fi
  http_code="$(echo "$result" | tail -1)"
  body="$(echo "$result" | sed '$d')"

  if [[ "$http_code" == "200" ]]; then
    echo "OK: reservation ${method} for $mac -> $ip (HTTP 200)"
    echo "$body" | jq -r '.data[] | "  mac: \(.mac)\n  ip: \(.fixed_ip)\n  name: \(.name)"' 2>/dev/null || true
  else
    echo "FAIL: HTTP $http_code"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
  fi
}

# ── Help ──
show_help() {
  cat <<'EOF'
unifi-home-agent.sh — CLI agent for home UniFi OS API

Usage:
  unifi-home-agent.sh auth                                         Test authentication
  unifi-home-agent.sh clients [--site S] [--json]                  List connected clients
  unifi-home-agent.sh reservations [--site S] [--json]             List DHCP reservations
  unifi-home-agent.sh wifi-list [--site S] [--json]                List configured WLANs
  unifi-home-agent.sh wifi-create --name N --passphrase P --band B Create WLAN
  unifi-home-agent.sh reservation-create --mac M --ip I --name N   Create DHCP reservation

Options:
  --site S         UniFi site name (default: "default")
  --json           Output raw JSON array (read-only commands)
  --name N         SSID name (wifi-create) or hostname (reservation-create)
  --passphrase P   WiFi passphrase (wifi-create)
  --band B         WiFi band: 2g, 5g, or both (wifi-create)
  --mac M          Device MAC address (reservation-create)
  --ip I           Fixed IP address (reservation-create)

Credentials (resolution order):
  1. UNIFI_HOME_USER / UNIFI_HOME_PASSWORD env vars (cookie auth)
  2. UNIFI_HOME_API_KEY env var (X-API-KEY auth — used by mutating commands)
  3. Infisical: home-assistant/prod keys via infisical-agent.sh get-cached

Host: UDR7 at udr-home from ssh.targets.yaml; API calls proxied through proxmox-home.
EOF
}

# ── Main ──
case "${1:-help}" in
  auth)               cmd_auth ;;
  clients)            shift; cmd_clients "$@" ;;
  reservations)       shift; cmd_reservations "$@" ;;
  wifi-list)          shift; cmd_wifi_list "$@" ;;
  wifi-create)        shift; cmd_wifi_create "$@" ;;
  reservation-create) shift; cmd_reservation_create "$@" ;;
  help|--help|-h) show_help ;;
  *) echo "Unknown command: $1" >&2; show_help; exit 1 ;;
esac
