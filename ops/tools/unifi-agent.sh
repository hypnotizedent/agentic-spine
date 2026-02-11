#!/usr/bin/env bash
# unifi-agent.sh — CLI agent for UniFi OS API (read-only first)
#
# Queries the UDR6 UniFi controller API through pve (LAN-only device).
# No web UI required.
#
# Commands:
#   auth                          Test authentication (no secrets printed)
#   clients [--site S] [--json]   List connected clients (MAC/IP/name)
#
# Credential resolution:
#   1. UNIFI_SHOP_USER / UNIFI_SHOP_PASSWORD env vars
#   2. Infisical via infisical-agent.sh get-cached
#
# Host: reads udr-shop from ssh.targets.yaml (default 192.168.1.1)
# API calls are proxied through pve via SSH (UDR6 is LAN-only).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SSH_BINDING="$SPINE_ROOT/ops/bindings/ssh.targets.yaml"
INFISICAL_AGENT="$SPINE_ROOT/ops/tools/infisical-agent.sh"

COOKIE_DIR="${HOME}/.cache/spine/unifi"
COOKIE_JAR="$COOKIE_DIR/cookies.txt"

stop(){ echo "STOP (2): $*" >&2; exit 2; }

command -v yq >/dev/null 2>&1 || stop "missing dependency: yq"
command -v jq >/dev/null 2>&1 || stop "missing dependency: jq"
command -v ssh >/dev/null 2>&1 || stop "missing dependency: ssh"
[[ -f "$SSH_BINDING" ]] || stop "missing binding: $SSH_BINDING"

# ── Resolve UDR host from ssh.targets.yaml ──
UDR_HOST="$(yq -r '.ssh.targets[] | select(.id == "udr-shop") | .host' "$SSH_BINDING")"
[[ -n "$UDR_HOST" && "$UDR_HOST" != "null" ]] || stop "udr-shop not found in ssh.targets.yaml"

# ── Resolve pve probe host ──
PVE_HOST="$(yq -r '.ssh.targets[] | select(.id == "pve") | .host' "$SSH_BINDING")"
PVE_USER="$(yq -r '.ssh.targets[] | select(.id == "pve") | .user // "root"' "$SSH_BINDING")"
[[ -n "$PVE_HOST" && "$PVE_HOST" != "null" ]] || stop "pve not found in ssh.targets.yaml"

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
  if [[ -n "${UNIFI_SHOP_USER:-}" && -n "${UNIFI_SHOP_PASSWORD:-}" ]]; then
    return 0
  fi

  if [[ -f "$INFISICAL_AGENT" ]]; then
    UNIFI_SHOP_USER="$("$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_SHOP_USER 2>/dev/null || true)"
    UNIFI_SHOP_PASSWORD="$("$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_SHOP_PASSWORD 2>/dev/null || true)"
  fi

  if [[ -z "${UNIFI_SHOP_USER:-}" || -z "${UNIFI_SHOP_PASSWORD:-}" ]]; then
    return 1
  fi
  return 0
}

# ── Run a script on pve via SSH (stdin), keeping secrets out of remote ps argv ──
pve_run() {
  ssh "${ssh_opts[@]}" "${PVE_USER}@${PVE_HOST}" "bash -s"
}

# ── Auth command ──
cmd_auth() {
  if ! resolve_creds; then
    echo "FAIL: UniFi credentials not available"
    echo "hint: set UNIFI_SHOP_USER + UNIFI_SHOP_PASSWORD env vars"
    echo "  or: ops cap run secrets.set.interactive infrastructure prod"
    echo "      then set keys UNIFI_SHOP_USER and UNIFI_SHOP_PASSWORD"
    exit 1
  fi

  echo "unifi-agent: auth"
  echo "host: $UDR_HOST (via pve $PVE_HOST)"

  # base64-encode creds locally to avoid shell-escaping issues through the heredoc
  local udr_b64 user_b64 pass_b64
  udr_b64="$(printf '%s' "$UDR_HOST" | base64)"
  user_b64="$(printf '%s' "$UNIFI_SHOP_USER" | base64)"
  pass_b64="$(printf '%s' "$UNIFI_SHOP_PASSWORD" | base64)"

  local auth_result
  auth_result="$(
    pve_run <<EOF
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
  -c /tmp/unifi_cookies.txt \
  -w '%{http_code}' -o /dev/null 2>/dev/null || true)"

rm -f /tmp/unifi_cookies.txt
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
    echo "FAIL: UniFi credentials not available" >&2
    exit 1
  fi

  # base64-encode creds locally to avoid shell-escaping issues through the heredoc
  local udr_b64 site_b64 user_b64 pass_b64
  udr_b64="$(printf '%s' "$UDR_HOST" | base64)"
  site_b64="$(printf '%s' "$site" | base64)"
  user_b64="$(printf '%s' "$UNIFI_SHOP_USER" | base64)"
  pass_b64="$(printf '%s' "$UNIFI_SHOP_PASSWORD" | base64)"

  local raw
  raw="$(
    pve_run <<EOF
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
  -c /tmp/unifi_cookies.txt \
  -o /dev/null 2>/dev/null

# Query clients
curl -sk "https://\${udr}/proxy/network/api/s/\${site}/stat/sta" -b /tmp/unifi_cookies.txt 2>/dev/null

rm -f /tmp/unifi_cookies.txt
EOF
  )" || {
    echo "FAIL: could not query UniFi API via pve" >&2
    exit 1
  }

  if [[ "$json_mode" -eq 1 ]]; then
    echo "$raw" | jq -r '[.data[] | {mac, ip, hostname: (.hostname // .name // "unknown"), name: (.name // .hostname // "unknown"), is_wired, last_seen}]' 2>/dev/null || {
      echo "FAIL: could not parse UniFi response" >&2
      echo "$raw" >&2
      exit 1
    }
  else
    echo "unifi-agent: clients (site=$site)"
    echo "host: $UDR_HOST (via pve $PVE_HOST)"
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
unifi-agent.sh — CLI agent for UniFi OS API

Usage:
  unifi-agent.sh auth                          Test authentication
  unifi-agent.sh clients [--site S] [--json]   List connected clients

Options:
  --site S    UniFi site name (default: "default")
  --json      Output raw JSON array

Credentials (resolution order):
  1. UNIFI_SHOP_USER / UNIFI_SHOP_PASSWORD env vars
  2. Infisical: infrastructure/prod keys via infisical-agent.sh get-cached

Host: UDR6 at udr-shop from ssh.targets.yaml; API calls proxied through pve.
EOF
}

# ── Main ──
case "${1:-help}" in
  auth)    cmd_auth ;;
  clients) shift; cmd_clients "$@" ;;
  help|--help|-h) show_help ;;
  *) echo "Unknown command: $1" >&2; show_help; exit 1 ;;
esac
