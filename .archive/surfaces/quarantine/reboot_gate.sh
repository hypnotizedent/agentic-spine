#!/usr/bin/env bash
# reboot_gate.sh - Pre/post reboot health gate
# Part of #610: Reboot Health Gate Checklist
#
# Usage: ./scripts/infra/reboot_gate.sh [--pre|--post] [--json]
#
# --pre   Run pre-reboot checks (default)
# --post  Run post-reboot checks
# --json  Output in JSON format
# --help  Show this help
#
# Requires: bash 4+, standard unix tools
# Optional: pvecm, qm, pct, zpool (Proxmox), tailscale

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Tier 1 hosts from DEVICE_IDENTITY_SSOT.md
TIER1_HOSTS=("pve" "docker-host" "proxmox-home" "macbook")

# Counters
PASS=0
FAIL=0
WARN=0

# Results for JSON
declare -a RESULTS=()

# Parse arguments
MODE="pre"
OUTPUT="text"
for arg in "$@"; do
  case $arg in
    --pre) MODE="pre" ;;
    --post) MODE="post" ;;
    --json) OUTPUT="json" ;;
    --help|-h)
      echo "Reboot Health Gate - Pre/post reboot validation"
      echo ""
      echo "Usage: $0 [--pre|--post] [--json]"
      echo ""
      echo "Options:"
      echo "  --pre   Run pre-reboot checks (default)"
      echo "  --post  Run post-reboot checks"
      echo "  --json  Output in JSON format"
      echo "  --help  Show this help"
      echo ""
      echo "Runbook: docs/runbooks/REBOOT_HEALTH_GATE.md"
      exit 0
      ;;
  esac
done

# Helper functions
log_pass() {
  local msg="$1"
  ((++PASS))
  if [[ "$OUTPUT" == "json" ]]; then
    RESULTS+=("{\"status\":\"PASS\",\"check\":\"$msg\"}")
  else
    echo -e "  ${GREEN}PASS${NC} $msg"
  fi
}

log_warn() {
  local msg="$1"
  ((++WARN))
  if [[ "$OUTPUT" == "json" ]]; then
    RESULTS+=("{\"status\":\"WARN\",\"check\":\"$msg\"}")
  else
    echo -e "  ${YELLOW}WARN${NC} $msg"
  fi
}

log_fail() {
  local msg="$1"
  ((++FAIL))
  if [[ "$OUTPUT" == "json" ]]; then
    RESULTS+=("{\"status\":\"FAIL\",\"check\":\"$msg\"}")
  else
    echo -e "  ${RED}FAIL${NC} $msg"
  fi
}

log_info() {
  local msg="$1"
  if [[ "$OUTPUT" != "json" ]]; then
    echo -e "  ${BLUE}INFO${NC} $msg"
  fi
}

section() {
  local title="$1"
  if [[ "$OUTPUT" != "json" ]]; then
    echo ""
    echo -e "${BLUE}[$title]${NC}"
  fi
}

# Check if command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Main checks
check_identity() {
  section "Identity"

  local hostname_val
  hostname_val=$(hostname 2>/dev/null || echo "unknown")
  log_info "Hostname: $hostname_val"

  local date_val
  date_val=$(date '+%Y-%m-%d %H:%M:%S')
  log_info "Timestamp: $date_val"

  if [[ -f /etc/os-release ]]; then
    local os_info
    os_info=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    log_info "OS: ${os_info:-unknown}"
  fi
}

check_connectivity() {
  section "Connectivity"

  # Gateway check (try common gateways)
  local gateway_found=false
  for gw in "192.168.12.1" "192.168.1.1" "10.0.0.1"; do
    if ping -c 1 -W 2 "$gw" &>/dev/null; then
      log_pass "Gateway $gw reachable"
      gateway_found=true
      break
    fi
  done

  if [[ "$gateway_found" == "false" ]]; then
    log_warn "No common gateway reachable (tried 192.168.12.1, 192.168.1.1, 10.0.0.1)"
  fi

  # Tier 1 hosts via Tailscale (if available)
  if has_cmd tailscale; then
    for host in "${TIER1_HOSTS[@]}"; do
      if tailscale ping -c 1 --timeout 3s "$host" &>/dev/null; then
        log_pass "Tailscale: $host reachable"
      else
        log_warn "Tailscale: $host unreachable (may be offline)"
      fi
    done
  else
    log_info "Tailscale not available, skipping mesh checks"
  fi
}

check_proxmox() {
  section "Proxmox"

  if ! has_cmd qm; then
    log_info "Not a Proxmox host (qm not found), skipping Proxmox checks"
    return
  fi

  # Cluster status
  if has_cmd pvecm; then
    if pvecm status &>/dev/null; then
      log_pass "Cluster status OK"
    else
      log_info "Single-node or cluster issue (pvecm status failed)"
    fi
  fi

  # VM status
  local running_vms stopped_vms
  running_vms=$(qm list 2>/dev/null | grep -c running || echo "0")
  stopped_vms=$(qm list 2>/dev/null | grep -c stopped || echo "0")

  log_info "VMs: $running_vms running, $stopped_vms stopped"

  if [[ "$stopped_vms" -gt 0 ]]; then
    log_warn "VMs stopped (verify this is intentional, not a 'network issue')"
    if [[ "$OUTPUT" != "json" ]]; then
      qm list 2>/dev/null | grep stopped | while read -r line; do
        echo "       $line"
      done
    fi
  fi

  # Container status (if any)
  if has_cmd pct; then
    local running_cts stopped_cts
    running_cts=$(pct list 2>/dev/null | grep -c running || echo "0")
    stopped_cts=$(pct list 2>/dev/null | grep -c stopped || echo "0")

    if [[ "$running_cts" -gt 0 || "$stopped_cts" -gt 0 ]]; then
      log_info "Containers: $running_cts running, $stopped_cts stopped"
    fi
  fi
}

check_storage() {
  section "Storage"

  # Root filesystem
  local root_usage
  root_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

  if [[ -n "$root_usage" ]]; then
    if [[ "$root_usage" -ge 90 ]]; then
      log_fail "Root filesystem at ${root_usage}% (critical!)"
    elif [[ "$root_usage" -ge 80 ]]; then
      log_warn "Root filesystem at ${root_usage}%"
    else
      log_pass "Root filesystem at ${root_usage}%"
    fi
  fi

  # ZFS pools (if available)
  if has_cmd zpool; then
    local pool_status
    pool_status=$(zpool list -H 2>/dev/null)

    if [[ -n "$pool_status" ]]; then
      # Check for degraded/faulted
      if zpool status 2>/dev/null | grep -qE "DEGRADED|FAULTED"; then
        log_fail "ZFS pool DEGRADED or FAULTED - DO NOT REBOOT"
      else
        local pool_count
        pool_count=$(zpool list -H 2>/dev/null | wc -l)
        log_pass "ZFS: $pool_count pool(s) healthy"
      fi
    fi
  else
    log_info "ZFS not available"
  fi
}

check_backups() {
  section "Backups"

  # Check for active vzdump
  if has_cmd pgrep && pgrep -x vzdump &>/dev/null; then
    log_fail "Backup (vzdump) in progress - DO NOT REBOOT"
  else
    log_pass "No active backup running"
  fi

  # Last backup info (if vzdump logs exist)
  if [[ -d /var/log/vzdump ]]; then
    local last_backup
    last_backup=$(ls -t /var/log/vzdump/*.log 2>/dev/null | head -1)
    if [[ -n "$last_backup" ]]; then
      local backup_date
      backup_date=$(stat -c %y "$last_backup" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$last_backup" 2>/dev/null)
      log_info "Last backup log: $backup_date"
    fi
  fi
}

check_autostart() {
  section "Autostart"

  if ! has_cmd qm; then
    log_info "Not a Proxmox host, skipping autostart check"
    return
  fi

  local autostart_count=0
  local no_autostart_vms=""

  while read -r vmid name status _rest; do
    [[ "$vmid" =~ ^[0-9]+$ ]] || continue

    local onboot
    onboot=$(qm config "$vmid" 2>/dev/null | grep -E "^onboot:" | awk '{print $2}')

    if [[ "$onboot" == "1" ]]; then
      ((++autostart_count))
    else
      no_autostart_vms+=" $vmid($name)"
    fi
  done < <(qm list 2>/dev/null | tail -n +2)

  log_info "VMs with autostart: $autostart_count"

  if [[ -n "$no_autostart_vms" ]]; then
    log_warn "VMs without autostart:$no_autostart_vms"
  fi
}

check_services() {
  section "Services"

  # Only run if we can reach external URLs
  if ! has_cmd curl; then
    log_info "curl not available, skipping service checks"
    return
  fi

  local services=(
    "https://mintprints-api.ronny.works/health|Mint API"
    "https://secrets.ronny.works/api/status|Infisical"
  )

  for svc in "${services[@]}"; do
    local url="${svc%|*}"
    local name="${svc#*|}"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" =~ ^2 ]]; then
      log_pass "$name (HTTP $http_code)"
    elif [[ "$http_code" == "000" ]]; then
      log_warn "$name unreachable (may be expected if VMs stopped)"
    else
      log_warn "$name HTTP $http_code"
    fi
  done
}

# Print summary
print_summary() {
  if [[ "$OUTPUT" == "json" ]]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
    echo "  \"mode\": \"$MODE\","
    echo "  \"hostname\": \"$(hostname 2>/dev/null || echo unknown)\","
    echo "  \"summary\": {\"pass\": $PASS, \"fail\": $FAIL, \"warn\": $WARN},"
    echo "  \"results\": ["
    local first=true
    for result in "${RESULTS[@]}"; do
      if [[ "$first" == "true" ]]; then
        echo "    $result"
        first=false
      else
        echo "    ,$result"
      fi
    done
    echo "  ]"
    echo "}"
  else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  Summary: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC} | ${YELLOW}$WARN warnings${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $FAIL -gt 0 ]]; then
      echo ""
      echo -e "${RED}STOP: $FAIL critical issue(s) found. Do NOT proceed with reboot.${NC}"
      exit 1
    elif [[ $WARN -gt 0 ]]; then
      echo ""
      echo -e "${YELLOW}CAUTION: $WARN warning(s). Verify before proceeding.${NC}"
      exit 0
    else
      echo ""
      echo -e "${GREEN}All checks passed. Safe to proceed.${NC}"
      exit 0
    fi
  fi
}

# Main
main() {
  if [[ "$OUTPUT" != "json" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  REBOOT HEALTH GATE"
    echo "  Mode: $MODE | $(date '+%Y-%m-%d %H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  check_identity
  check_connectivity
  check_proxmox
  check_storage
  check_backups

  if [[ "$MODE" == "pre" ]]; then
    check_autostart
  fi

  if [[ "$MODE" == "post" ]]; then
    check_services
  fi

  print_summary
}

main "$@"
