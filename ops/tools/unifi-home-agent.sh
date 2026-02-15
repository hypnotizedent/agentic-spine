#!/usr/bin/env bash
# unifi-home-agent.sh — CLI agent for home UniFi OS API (read-only)
#
# Queries the UDR7 UniFi controller API through proxmox-home (LAN-only device).
# Mirrors unifi-agent.sh (shop) for home network.
#
# Commands:
#   auth                          Test authentication (no secrets printed)
#   clients [--site S] [--json]   List connected clients (MAC/IP/name)
#
# Credential resolution:
#   1. UNIFI_HOME_USER / UNIFI_HOME_PASSWORD env vars
#   2. Infisical via infisical-agent.sh get-cached (home-assistant project)
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

# ── Help ──
show_help() {
  cat <<'EOF'
unifi-home-agent.sh — CLI agent for home UniFi OS API

Usage:
  unifi-home-agent.sh auth                          Test authentication
  unifi-home-agent.sh clients [--site S] [--json]   List connected clients

Options:
  --site S    UniFi site name (default: "default")
  --json      Output raw JSON array

Credentials (resolution order):
  1. UNIFI_HOME_USER / UNIFI_HOME_PASSWORD env vars
  2. Infisical: home-assistant/prod keys via infisical-agent.sh get-cached

Host: UDR7 at udr-home from ssh.targets.yaml; API calls proxied through proxmox-home.
EOF
}

# ── Main ──
case "${1:-help}" in
  auth)    cmd_auth ;;
  clients) shift; cmd_clients "$@" ;;
  help|--help|-h) show_help ;;
  *) echo "Unknown command: $1" >&2; show_help; exit 1 ;;
esac
