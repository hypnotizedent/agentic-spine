#!/usr/bin/env bash
# TRIAGE: Enforce report-first mint-data persistence and Redis durability contract checks without runtime mutation.
# D236: mint-data-persistence-lock
# Report/enforce mint-data persistence baseline (postgres/minio/redis mounts + redis durability posture).
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
STORAGE_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
GUARD_POLICY="$ROOT/ops/bindings/mint.storage.guard.policy.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d236-mint-data-persistence-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D236 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$SSH_BINDING" ]] || { echo "D236 FAIL: missing $SSH_BINDING" >&2; exit 1; }
[[ -f "$STORAGE_POLICY" ]] || { echo "D236 FAIL: missing $STORAGE_POLICY" >&2; exit 1; }
[[ -f "$GUARD_POLICY" ]] || { echo "D236 FAIL: missing $GUARD_POLICY" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D236 FAIL: yq missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$GUARD_POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D236 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

ssh_host="$(yq -r '.ssh.targets[] | select(.id == "mint-data") | .host // ""' "$SSH_BINDING" 2>/dev/null || true)"
ssh_user="$(yq -r '.ssh.targets[] | select(.id == "mint-data") | .user // "ubuntu"' "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
[[ -n "$ssh_host" ]] || { echo "D236 FAIL: mint-data ssh target missing" >&2; exit 1; }

require_appendonly="$(yq -r '.mint_data_contract.redis.require_appendonly // true' "$GUARD_POLICY" 2>/dev/null || echo true)"
required_prefix="$(yq -r '.mint_data_contract.redis.require_named_volume_prefix // "mint-data_"' "$GUARD_POLICY" 2>/dev/null || echo mint-data_)"
target_tier="$(yq -r '.vm_storage.mint-data.target_storage_tier // ""' "$STORAGE_POLICY" 2>/dev/null || true)"

ref="$ssh_user@$ssh_host"
opts=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if ! ssh "${opts[@]}" "$ref" "true" >/dev/null 2>&1; then
  echo "D236 FAIL: ssh unreachable ($ref)" >&2
  exit 1
fi

root_dev="$(ssh "${opts[@]}" "$ref" "findmnt -n -o SOURCE --target /" 2>/dev/null || true)"

pg="$(ssh "${opts[@]}" "$ref" "docker ps --format '{{.Names}}' | grep -E 'postgres' | head -1" 2>/dev/null || true)"
minio="$(ssh "${opts[@]}" "$ref" "docker ps --format '{{.Names}}' | grep -E 'minio' | head -1" 2>/dev/null || true)"
redis="$(ssh "${opts[@]}" "$ref" "docker ps --format '{{.Names}}' | grep -E 'redis' | head -1" 2>/dev/null || true)"

[[ -n "$pg" ]] || finding "HIGH" "STOR-003: postgres container missing on mint-data"
[[ -n "$minio" ]] || finding "HIGH" "STOR-003: minio container missing on mint-data"
[[ -n "$redis" ]] || finding "HIGH" "STOR-003: redis container missing on mint-data"

check_mount_nonboot() {
  local container="$1"
  local destination="$2"
  [[ -n "$container" ]] || return 0
  local source source_dev
  source="$(ssh "${opts[@]}" "$ref" "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"$destination\"}}{{.Source}}{{end}}{{end}}' '$container'" 2>/dev/null || true)"
  source="$(echo "$source" | tr -d '\r' | xargs || true)"
  if [[ -z "$source" ]]; then
    finding "HIGH" "STOR-003: $container missing mount for $destination"
    return
  fi
  source_dev="$(ssh "${opts[@]}" "$ref" "findmnt -n -o SOURCE --target '$source'" 2>/dev/null || true)"
  if [[ "$target_tier" != "boot-only" && -n "$root_dev" && -n "$source_dev" && "$source_dev" == "$root_dev" ]]; then
    finding "HIGH" "STOR-002: $container mount $destination resolves to boot device ($source_dev)"
  fi
}

check_mount_nonboot "$pg" "/var/lib/postgresql/data"
check_mount_nonboot "$minio" "/data"
check_mount_nonboot "$redis" "/data"

if [[ -n "$redis" ]]; then
  redis_appendonly="$(ssh "${opts[@]}" "$ref" "docker exec '$redis' redis-cli CONFIG GET appendonly | tail -n1" 2>/dev/null | tr -d '\r' | xargs || true)"
  redis_save="$(ssh "${opts[@]}" "$ref" "docker exec '$redis' redis-cli CONFIG GET save | tail -n1" 2>/dev/null | tr -d '\r' | xargs || true)"
  redis_source="$(ssh "${opts[@]}" "$ref" "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/data\"}}{{.Source}}{{end}}{{end}}' '$redis'" 2>/dev/null | tr -d '\r' | xargs || true)"

  if [[ "$require_appendonly" == "true" && "$redis_appendonly" != "yes" ]]; then
    finding "MEDIUM" "STOR-003: redis appendonly=$redis_appendonly (expected yes)"
  fi
  if [[ -z "$redis_save" ]]; then
    finding "MEDIUM" "STOR-003: redis save cadence is empty"
  fi
  if [[ -n "$required_prefix" && "$redis_source" != *"/volumes/${required_prefix}"* ]]; then
    finding "MEDIUM" "STOR-003: redis volume source '$redis_source' does not match required prefix '$required_prefix'"
  fi
fi

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D236 FAIL: mint-data persistence findings=$FINDINGS"
    exit 1
  fi
  echo "D236 REPORT: mint-data persistence findings=$FINDINGS"
  exit 0
fi

echo "D236 PASS: mint-data persistence lock"
exit 0
