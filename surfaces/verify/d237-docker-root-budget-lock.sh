#!/usr/bin/env bash
# TRIAGE: Enforce report-first docker-root budget thresholds for root usage, images, build cache, and local volumes on mint hosts.
# D237: docker-root-budget-lock
# Report/enforce boot-root and docker footprint budget thresholds for mint-data/mint-apps.
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
GUARD_POLICY="$ROOT/ops/bindings/mint.storage.guard.policy.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d237-docker-root-budget-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D237 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$SSH_BINDING" ]] || { echo "D237 FAIL: missing $SSH_BINDING" >&2; exit 1; }
[[ -f "$GUARD_POLICY" ]] || { echo "D237 FAIL: missing $GUARD_POLICY" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D237 FAIL: yq missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$GUARD_POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D237 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

root_warn_pct="$(yq -r '.thresholds.root_usage_warn_pct // 60' "$GUARD_POLICY" 2>/dev/null || echo 60)"
images_warn_gb="$(yq -r '.thresholds.docker_images_warn_gb // 15' "$GUARD_POLICY" 2>/dev/null || echo 15)"
build_warn_gb="$(yq -r '.thresholds.docker_build_cache_warn_gb // 10' "$GUARD_POLICY" 2>/dev/null || echo 10)"
volumes_warn_gb="$(yq -r '.thresholds.docker_local_volumes_warn_gb // 30' "$GUARD_POLICY" 2>/dev/null || echo 30)"

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

to_gb() {
  local raw="$(echo "${1:-0}" | tr -d ' ' | tr '[:lower:]' '[:upper:]')"
  if [[ "$raw" =~ ^([0-9]+(\.[0-9]+)?)(B|KB|MB|GB|TB)$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[3]}"
    case "$unit" in
      B) awk -v n="$num" 'BEGIN { printf "%.6f", n / 1024 / 1024 / 1024 }' ;;
      KB) awk -v n="$num" 'BEGIN { printf "%.6f", n / 1024 / 1024 }' ;;
      MB) awk -v n="$num" 'BEGIN { printf "%.6f", n / 1024 }' ;;
      GB) awk -v n="$num" 'BEGIN { printf "%.6f", n }' ;;
      TB) awk -v n="$num" 'BEGIN { printf "%.6f", n * 1024 }' ;;
    esac
    return
  fi
  echo "0"
}

ge() {
  local a="$1" b="$2"
  awk -v a="$a" -v b="$b" 'BEGIN { exit !(a >= b) }'
}

check_host() {
  local host="$1"
  local ssh_host ssh_user ref root_pct summary images_sz build_sz volumes_sz images_gb build_gb volumes_gb

  ssh_host="$(yq -r ".ssh.targets[] | select(.id == \"$host\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  ssh_user="$(yq -r ".ssh.targets[] | select(.id == \"$host\") | .user // \"ubuntu\"" "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
  [[ -n "$ssh_host" ]] || { finding "HIGH" "$host: missing ssh target"; return; }

  ref="$ssh_user@$ssh_host"
  local opts=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

  if ! ssh "${opts[@]}" "$ref" "true" >/dev/null 2>&1; then
    finding "HIGH" "$host: ssh unreachable ($ref)"
    return
  fi

  root_pct="$(ssh "${opts[@]}" "$ref" "df --output=pcent / | tail -1 | tr -d ' %'" 2>/dev/null || true)"
  summary="$(ssh "${opts[@]}" "$ref" "docker system df --format '{{.Type}}|{{.Size}}'" 2>/dev/null || true)"

  if [[ -n "$root_pct" && "$root_pct" =~ ^[0-9]+$ ]] && (( root_pct >= root_warn_pct )); then
    finding "MEDIUM" "$host: root usage ${root_pct}% >= warn ${root_warn_pct}%"
  fi

  images_sz="$(echo "$summary" | awk -F'|' '$1=="Images" {print $2; exit}')"
  build_sz="$(echo "$summary" | awk -F'|' '$1=="Build Cache" {print $2; exit}')"
  volumes_sz="$(echo "$summary" | awk -F'|' '$1=="Local Volumes" {print $2; exit}')"

  images_gb="$(to_gb "$images_sz")"
  build_gb="$(to_gb "$build_sz")"
  volumes_gb="$(to_gb "$volumes_sz")"

  if ge "$images_gb" "$images_warn_gb"; then
    finding "MEDIUM" "$host: docker images ${images_gb}GB >= warn ${images_warn_gb}GB"
  fi
  if ge "$build_gb" "$build_warn_gb"; then
    finding "MEDIUM" "$host: docker build cache ${build_gb}GB >= warn ${build_warn_gb}GB"
  fi
  if [[ "$host" == "mint-data" ]] && ge "$volumes_gb" "$volumes_warn_gb"; then
    finding "MEDIUM" "$host: docker local volumes ${volumes_gb}GB >= warn ${volumes_warn_gb}GB"
  fi
}

check_host "mint-data"
check_host "mint-apps"

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D237 FAIL: docker root budget findings=$FINDINGS"
    exit 1
  fi
  echo "D237 REPORT: docker root budget findings=$FINDINGS"
  exit 0
fi

echo "D237 PASS: docker root budget lock"
exit 0
