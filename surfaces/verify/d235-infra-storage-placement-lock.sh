#!/usr/bin/env bash
# TRIAGE: Enforce report-first infra storage placement drift detection and docker-root-on-boot cluster invariants for mint-data/mint-apps.
# D235: infra-storage-placement-lock
# Report/enforce drift between storage placement policy and live docker-root placement for mint-data/mint-apps.
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
STORAGE_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
MAP_FILE="$ROOT/ops/bindings/mint.storage.findings.map.yaml"
GUARD_POLICY="$ROOT/ops/bindings/mint.storage.guard.policy.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d235-infra-storage-placement-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D235 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$SSH_BINDING" ]] || { echo "D235 FAIL: missing $SSH_BINDING" >&2; exit 1; }
[[ -f "$STORAGE_POLICY" ]] || { echo "D235 FAIL: missing $STORAGE_POLICY" >&2; exit 1; }
[[ -f "$MAP_FILE" ]] || { echo "D235 FAIL: missing $MAP_FILE" >&2; exit 1; }
[[ -f "$GUARD_POLICY" ]] || { echo "D235 FAIL: missing $GUARD_POLICY" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D235 FAIL: yq missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$GUARD_POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D235 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

cluster_line="$(yq -r '.root_cause_clusters[] | select(.id == "docker-root-on-boot") | .stor_findings | join(",")' "$MAP_FILE" 2>/dev/null || true)"
if [[ "$cluster_line" != *"STOR-002"* || "$cluster_line" != *"STOR-004"* ]]; then
  finding "HIGH" "mapping drift: docker-root-on-boot cluster must include STOR-002 and STOR-004"
fi

check_host() {
  local host="$1"
  local ssh_host ssh_user target_tier root_dev docker_root docker_dev

  ssh_host="$(yq -r ".ssh.targets[] | select(.id == \"$host\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  ssh_user="$(yq -r ".ssh.targets[] | select(.id == \"$host\") | .user // \"ubuntu\"" "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
  target_tier="$(yq -r ".vm_storage.\"$host\".target_storage_tier // \"\"" "$STORAGE_POLICY" 2>/dev/null || true)"

  if [[ -z "$ssh_host" ]]; then
    finding "HIGH" "$host: missing ssh target binding"
    return
  fi
  if [[ -z "$target_tier" ]]; then
    finding "HIGH" "$host: missing target_storage_tier in infra.storage.placement.policy.yaml"
    return
  fi

  local ref="$ssh_user@$ssh_host"
  local opts=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

  if ! ssh "${opts[@]}" "$ref" "true" >/dev/null 2>&1; then
    finding "HIGH" "$host: ssh unreachable ($ref)"
    return
  fi

  root_dev="$(ssh "${opts[@]}" "$ref" "findmnt -n -o SOURCE --target /" 2>/dev/null || true)"
  docker_root="$(ssh "${opts[@]}" "$ref" "docker info 2>/dev/null | awk -F': ' '/Docker Root Dir/ {print \$2}'" 2>/dev/null || true)"
  docker_root="${docker_root:-/var/lib/docker}"
  docker_dev="$(ssh "${opts[@]}" "$ref" "findmnt -n -o SOURCE --target '${docker_root}'" 2>/dev/null || true)"

  if [[ -z "$root_dev" || -z "$docker_dev" ]]; then
    finding "HIGH" "$host: unresolved filesystem device(s) root='$root_dev' docker='$docker_dev'"
    return
  fi

  if [[ "$target_tier" != "boot-only" && "$root_dev" == "$docker_dev" ]]; then
    finding "HIGH" "$host: docker-root-on-boot drift (target_tier=$target_tier docker_root=$docker_root dev=$docker_dev)"
  fi

  if [[ "$host" == "mint-apps" && "$target_tier" == "boot-only" && "$root_dev" != "$docker_dev" ]]; then
    finding "MEDIUM" "$host: unexpected non-boot docker root while policy target is boot-only"
  fi
}

check_host "mint-data"
check_host "mint-apps"

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D235 FAIL: infra storage placement drift findings=$FINDINGS"
    exit 1
  fi
  echo "D235 REPORT: infra storage placement drift findings=$FINDINGS"
  exit 0
fi

echo "D235 PASS: infra storage placement lock"
exit 0
